#!/usr/bin/env python3
"""
Document Reader Service - Native Python Implementation

This service converts PDF documents to markdown using the marker-pdf library
and uploads the results to S3. It replaces the previous bash-based entrypoint.sh
with a native Python implementation using the marker SDK.
"""

import os
import sys
import json
import logging
import io
import psutil
import gc
from datetime import datetime
from typing import List, Dict, Optional, Tuple
import traceback

import boto3
from botocore.exceptions import ClientError, BotoCoreError
from marker.converters.pdf import PdfConverter
from marker.models import create_model_dict
from marker.config.parser import ConfigParser


class DocumentProcessor:
    """
    Handles PDF to Markdown conversion using marker-pdf and S3 operations.
    """
    
    def __init__(self):
        """Initialize the document processor with configuration and clients."""
        self.setup_logging()
        self.logger = logging.getLogger(__name__)
        
        # Environment configuration
        self.s3_uri = None
        self.input_s3_bucket = None
        self.input_s3_key = None
        self.processing_timestamp = datetime.utcnow().strftime("%Y-%m-%d-%H-%M-%S")
        
        # AWS clients
        self.s3_client = None
        
        # Marker converter
        self.pdf_converter = None
        
        # Processing statistics
        self.stats = {
            'pdfs_found': 0,
            'pdfs_processed': 0,
            'markdowns_uploaded': 0,
            'failed_conversions': 0,
            'failed_uploads': 0
        }
        
    def setup_logging(self):
        """Configure structured logging for CloudWatch."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        # Set boto3 logging to WARNING to reduce noise
        logging.getLogger('boto3').setLevel(logging.WARNING)
        logging.getLogger('botocore').setLevel(logging.WARNING)
        logging.getLogger('urllib3').setLevel(logging.WARNING)
    
    def log_structured(self, level: str, message: str, **kwargs):
        """Log structured data for better CloudWatch parsing."""
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': level,
            'message': message,
            'processing_timestamp': self.processing_timestamp,
            **kwargs
        }
        
        if level.upper() == 'ERROR':
            self.logger.error(json.dumps(log_data))
        elif level.upper() == 'WARNING':
            self.logger.warning(json.dumps(log_data))
        else:
            self.logger.info(json.dumps(log_data))
    
    def log_memory_usage(self, context: str):
        """Log current memory usage for monitoring."""
        try:
            process = psutil.Process()
            memory_info = process.memory_info()
            memory_mb = memory_info.rss / 1024 / 1024
            
            # Get system memory if available
            try:
                system_memory = psutil.virtual_memory()
                available_mb = system_memory.available / 1024 / 1024
                total_mb = system_memory.total / 1024 / 1024
            except:
                available_mb = None
                total_mb = None
            
            self.log_structured('INFO', f'Memory usage - {context}', 
                              memory_mb=round(memory_mb, 2),
                              available_mb=round(available_mb, 2) if available_mb else None,
                              total_mb=round(total_mb, 2) if total_mb else None)
        except Exception as e:
            self.log_structured('WARNING', 'Failed to get memory usage', error=str(e))
    
    def validate_environment(self) -> bool:
        """
        Validate required environment variables and initialize clients.
        
        Returns:
            bool: True if validation passes, False otherwise
        """
        self.log_structured('INFO', 'Starting environment validation')
        self.log_memory_usage('startup')
        
        # Check required environment variables
        self.s3_uri = os.getenv('S3_URI')
        
        if not self.s3_uri:
            self.log_structured('ERROR', 'S3_URI environment variable not set')
            return False
        
        # Parse S3 URI to extract bucket and key
        try:
            if not self.s3_uri.startswith('s3://'):
                self.log_structured('ERROR', 'S3_URI must start with s3://', s3_uri=self.s3_uri)
                return False
            
            # Remove s3:// prefix and split into bucket and key
            s3_path = self.s3_uri[5:]  # Remove 's3://'
            parts = s3_path.split('/', 1)
            
            if len(parts) != 2:
                self.log_structured('ERROR', 'Invalid S3_URI format, expected s3://bucket/key', s3_uri=self.s3_uri)
                return False
                
            self.input_s3_bucket = parts[0]
            self.input_s3_key = parts[1]
            
            self.log_structured('INFO', 'S3 URI parsed successfully',
                              bucket=self.input_s3_bucket,
                              key=self.input_s3_key)
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to parse S3_URI', s3_uri=self.s3_uri, error=str(e))
            return False
        
        # Initialize AWS clients
        try:
            self.s3_client = boto3.client('s3')
            self.log_structured('INFO', 'AWS S3 client initialized successfully')
        except Exception as e:
            self.log_structured('ERROR', 'Failed to initialize AWS S3 client', error=str(e))
            return False
        
        # Initialize marker converter
        try:
            self.log_structured('INFO', 'Initializing marker PDF converter')
            
            # Configure marker for optimal processing
            config = {
                'output_format': 'markdown',
                'disable_image_extraction': True,  # Disable for faster processing
                'workers': 1  # Single worker for container environment
            }
            
            config_parser = ConfigParser(config)
            
            self.pdf_converter = PdfConverter(
                config=config_parser.generate_config_dict(),
                artifact_dict=create_model_dict(),
                processor_list=config_parser.get_processors(),
                renderer=config_parser.get_renderer()
            )
            
            self.log_structured('INFO', 'Marker PDF converter initialized successfully')
            self.log_memory_usage('after_model_loading')
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to initialize marker PDF converter', 
                              error=str(e), traceback=traceback.format_exc())
            return False
        
        self.log_structured('INFO', 'Environment validation completed successfully',
                          s3_uri=self.s3_uri,
                          input_bucket=self.input_s3_bucket,
                          input_key=self.input_s3_key)
        return True
    
    def validate_pdf_file(self) -> bool:
        """
        Validate that the specified S3 object exists and is a PDF file.
        
        Returns:
            bool: True if valid PDF file exists, False otherwise
        """
        try:
            # Check if the file exists and get metadata
            response = self.s3_client.head_object(Bucket=self.input_s3_bucket, Key=self.input_s3_key)
            
            # Validate it's a PDF file
            if not self.input_s3_key.lower().endswith('.pdf'):
                self.log_structured('ERROR', 'File is not a PDF', s3_key=self.input_s3_key)
                return False
            
            file_size = response.get('ContentLength', 0)
            self.log_structured('INFO', 'PDF file validated successfully', 
                              s3_key=self.input_s3_key,
                              file_size_bytes=file_size,
                              file_size_mb=round(file_size / (1024 * 1024), 2))
            
            self.stats['pdfs_found'] = 1
            return True
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                self.log_structured('ERROR', 'PDF file not found in S3', s3_key=self.input_s3_key)
            else:
                self.log_structured('ERROR', 'Failed to validate PDF file', 
                                  s3_key=self.input_s3_key, error=str(e))
            return False
        except Exception as e:
            self.log_structured('ERROR', 'Unexpected error validating PDF file', 
                              s3_key=self.input_s3_key, error=str(e))
            return False
    
    def download_and_process_pdf(self) -> Optional[Tuple[str, Dict]]:
        """
        Download PDF from S3 to memory and process it with marker in one operation.
            
        Returns:
            Tuple of (markdown_content, metadata) or None if failed
        """
        try:
            self.log_structured('INFO', 'Processing PDF from S3', s3_key=self.input_s3_key)
            
            # Download PDF directly to memory
            pdf_obj = self.s3_client.get_object(Bucket=self.input_s3_bucket, Key=self.input_s3_key)
            pdf_bytes = pdf_obj['Body'].read()
            
            # Log file size for monitoring
            file_size_mb = len(pdf_bytes) / (1024 * 1024)
            self.log_structured('INFO', 'PDF downloaded to memory', 
                              s3_key=self.input_s3_key, 
                              size_mb=round(file_size_mb, 2))
            self.log_memory_usage('after_pdf_download')
            
            # Create BytesIO buffer for marker processing
            pdf_buffer = io.BytesIO(pdf_bytes)
            
            # Process with marker converter
            self.log_memory_usage('before_processing')
            result = self.pdf_converter(pdf_buffer)
            self.log_memory_usage('after_processing')
            
            # Clean up the buffer
            pdf_buffer.close()
            del pdf_bytes  # Explicitly free memory
            gc.collect()  # Force garbage collection
            self.log_memory_usage('after_cleanup')
            
            if hasattr(result, 'markdown') and result.markdown:
                markdown_content = result.markdown
                metadata = getattr(result, 'metadata', {})
                
                self.log_structured('INFO', 'PDF processed successfully', 
                                  s3_key=self.input_s3_key,
                                  markdown_length=len(markdown_content))
                
                self.stats['pdfs_processed'] += 1
                return markdown_content, metadata
            else:
                self.log_structured('ERROR', 'No markdown content generated', s3_key=self.input_s3_key)
                self.stats['failed_conversions'] += 1
                return None
                
        except ClientError as e:
            self.log_structured('ERROR', 'Failed to download PDF from S3', 
                              s3_key=self.input_s3_key, 
                              error=str(e))
            self.stats['failed_conversions'] += 1
            return None
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to process PDF', 
                              s3_key=self.input_s3_key, 
                              error=str(e),
                              traceback=traceback.format_exc())
            self.stats['failed_conversions'] += 1
            return None
    
    def upload_markdown_to_s3(self, markdown_content: str, metadata: Dict = None) -> bool:
        """
        Upload markdown content to the same folder as the source PDF.
        
        Args:
            markdown_content: The markdown text to upload
            metadata: Optional metadata from marker processing
            
        Returns:
            bool: True if upload successful, False otherwise
        """
        try:
            # Extract filename and folder from the input S3 key
            original_filename = self.input_s3_key.split('/')[-1]  # Get filename from S3 key
            base_name = original_filename.rsplit('.', 1)[0]  # Remove .pdf extension
            
            # Get the folder path (everything except the filename)
            folder_path = '/'.join(self.input_s3_key.split('/')[:-1])
            
            # Create output key in the same folder
            output_key = f"{folder_path}/{base_name}.md"
            
            # Prepare metadata for S3 object
            s3_metadata = {
                'processing-timestamp': self.processing_timestamp,
                'original-s3-key': self.input_s3_key,
                'original-filename': original_filename,
                'content-type': 'text/markdown'
            }
            
            if metadata:
                # Add marker metadata if available (convert to strings)
                for key, value in metadata.items():
                    if isinstance(value, (str, int, float)):
                        s3_metadata[f'marker-{key}'] = str(value)
            
            # Use the same bucket as input
            output_bucket = self.input_s3_bucket
            
            self.log_structured('INFO', 'Uploading markdown to S3', 
                              output_bucket=output_bucket,
                              output_key=output_key,
                              content_length=len(markdown_content))
            
            # Upload to S3 with UTF-8 encoding
            self.s3_client.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=markdown_content.encode('utf-8'),
                ContentType='text/markdown',
                Metadata=s3_metadata
            )
            
            self.log_structured('INFO', 'Markdown uploaded successfully', 
                              output_bucket=output_bucket,
                              output_key=output_key)
            self.stats['markdowns_uploaded'] += 1
            return True
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to upload markdown', 
                              output_key=output_key, 
                              error=str(e))
            self.stats['failed_uploads'] += 1
            return False
    
    
    def run(self) -> bool:
        """
        Main processing orchestration method.
        
        Returns:
            bool: True if processing completed successfully, False otherwise
        """
        self.log_structured('INFO', 'Document processing started (single file mode)')
        
        try:
            # Step 1: Validate environment and initialize clients
            if not self.validate_environment():
                return False
            
            # Step 2: Validate the specified PDF file
            if not self.validate_pdf_file():
                self.log_structured('ERROR', 'PDF file validation failed')
                return False
            
            # Step 3: Process the single PDF file
            self.log_structured('INFO', 'Starting PDF processing', 
                              s3_key=self.input_s3_key)
            
            # Process PDF directly from S3 to markdown
            result = self.download_and_process_pdf()
            
            if result:
                markdown_content, metadata = result
                
                # Upload markdown to S3 (same folder as PDF)
                self.upload_markdown_to_s3(markdown_content, metadata)
            else:
                self.log_structured('ERROR', 'Failed to process PDF file')
                return False
            
            # Step 4: Log final statistics
            self.log_structured('INFO', 'Document processing completed', 
                              stats=self.stats)
            
            # Check if we had any successful conversions
            if self.stats['markdowns_uploaded'] == 0:
                self.log_structured('ERROR', 'No markdown files were successfully uploaded')
                return False
            
            # Log warnings if some files failed
            if self.stats['failed_conversions'] > 0 or self.stats['failed_uploads'] > 0:
                self.log_structured('WARNING', 'Some files failed to process', stats=self.stats)
                
            # Success if at least one file was processed
            success_rate = self.stats['markdowns_uploaded'] / self.stats['pdfs_found']
            self.log_structured('INFO', 'Processing summary', 
                              success_rate=f"{success_rate:.2%}",
                              total_found=self.stats['pdfs_found'],
                              successfully_uploaded=self.stats['markdowns_uploaded'])
            
            return True
            
        except Exception as e:
            self.log_structured('ERROR', 'Unexpected error during processing', 
                              error=str(e), 
                              traceback=traceback.format_exc())
            return False


def main():
    """Main entry point for the document processing service."""
    processor = DocumentProcessor()
    
    try:
        success = processor.run()
        
        if success:
            processor.log_structured('INFO', 'Document processing service completed successfully')
            sys.exit(0)
        else:
            processor.log_structured('ERROR', 'Document processing service failed')
            sys.exit(1)
            
    except KeyboardInterrupt:
        processor.log_structured('WARNING', 'Document processing interrupted by user')
        sys.exit(130)  # Standard exit code for SIGINT
    
    except Exception as e:
        processor.log_structured('ERROR', 'Unexpected error in main', 
                                error=str(e), 
                                traceback=traceback.format_exc())
        sys.exit(1)


if __name__ == '__main__':
    main()