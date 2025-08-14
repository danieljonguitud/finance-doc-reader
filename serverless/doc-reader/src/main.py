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
        self.input_s3_bucket = None
        self.output_s3_uri_prefix = None
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
    
    def validate_environment(self) -> bool:
        """
        Validate required environment variables and initialize clients.
        
        Returns:
            bool: True if validation passes, False otherwise
        """
        self.log_structured('INFO', 'Starting environment validation')
        
        # Check required environment variables
        self.input_s3_bucket = os.getenv('INPUT_S3_BUCKET')
        self.output_s3_uri_prefix = os.getenv('OUTPUT_S3_URI_PREFIX')
        
        if not self.input_s3_bucket:
            self.log_structured('ERROR', 'INPUT_S3_BUCKET environment variable not set')
            return False
            
        if not self.output_s3_uri_prefix:
            self.log_structured('ERROR', 'OUTPUT_S3_URI_PREFIX environment variable not set')
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
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to initialize marker PDF converter', 
                              error=str(e), traceback=traceback.format_exc())
            return False
        
        self.log_structured('INFO', 'Environment validation completed successfully',
                          input_bucket=self.input_s3_bucket,
                          output_prefix=self.output_s3_uri_prefix)
        return True
    
    def list_pdf_objects_in_s3(self) -> List[Dict]:
        """
        List all PDF objects in the S3 input bucket.
        
        Returns:
            List[Dict]: List of S3 object metadata for PDF files
        """
        self.log_structured('INFO', 'Listing PDF objects in S3', bucket=self.input_s3_bucket)
        
        pdf_objects = []
        
        try:
            # List all objects in the bucket with .pdf extension
            paginator = self.s3_client.get_paginator('list_objects_v2')
            page_iterator = paginator.paginate(Bucket=self.input_s3_bucket)
            
            for page in page_iterator:
                if 'Contents' in page:
                    for obj in page['Contents']:
                        if obj['Key'].lower().endswith('.pdf'):
                            pdf_objects.append(obj)
            
            self.stats['pdfs_found'] = len(pdf_objects)
            
            if not pdf_objects:
                self.log_structured('WARNING', 'No PDF files found in S3 bucket')
            else:
                self.log_structured('INFO', f'Found {len(pdf_objects)} PDF files in S3')
            
            return pdf_objects
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to list PDF objects in S3', error=str(e))
            return []
    
    def download_and_process_pdf(self, s3_key: str) -> Optional[Tuple[str, Dict]]:
        """
        Download PDF from S3 to memory and process it with marker in one operation.
        
        Args:
            s3_key: S3 object key for the PDF file
            
        Returns:
            Tuple of (markdown_content, metadata) or None if failed
        """
        try:
            self.log_structured('INFO', 'Processing PDF from S3', s3_key=s3_key)
            
            # Download PDF directly to memory
            pdf_obj = self.s3_client.get_object(Bucket=self.input_s3_bucket, Key=s3_key)
            pdf_bytes = pdf_obj['Body'].read()
            
            # Log file size for monitoring
            file_size_mb = len(pdf_bytes) / (1024 * 1024)
            self.log_structured('INFO', 'PDF downloaded to memory', 
                              s3_key=s3_key, 
                              size_mb=round(file_size_mb, 2))
            
            # Create BytesIO buffer for marker processing
            pdf_buffer = io.BytesIO(pdf_bytes)
            
            # Process with marker converter
            result = self.pdf_converter(pdf_buffer)
            
            # Clean up the buffer
            pdf_buffer.close()
            del pdf_bytes  # Explicitly free memory
            
            if hasattr(result, 'markdown') and result.markdown:
                markdown_content = result.markdown
                metadata = getattr(result, 'metadata', {})
                
                self.log_structured('INFO', 'PDF processed successfully', 
                                  s3_key=s3_key,
                                  markdown_length=len(markdown_content))
                
                self.stats['pdfs_processed'] += 1
                return markdown_content, metadata
            else:
                self.log_structured('ERROR', 'No markdown content generated', s3_key=s3_key)
                self.stats['failed_conversions'] += 1
                return None
                
        except ClientError as e:
            self.log_structured('ERROR', 'Failed to download PDF from S3', 
                              s3_key=s3_key, 
                              error=str(e))
            self.stats['failed_conversions'] += 1
            return None
            
        except Exception as e:
            self.log_structured('ERROR', 'Failed to process PDF', 
                              s3_key=s3_key, 
                              error=str(e),
                              traceback=traceback.format_exc())
            self.stats['failed_conversions'] += 1
            return None
    
    def upload_markdown_to_s3(self, markdown_content: str, s3_key: str, metadata: Dict = None) -> bool:
        """
        Upload markdown content directly to S3 with timestamped naming.
        
        Args:
            markdown_content: The markdown text to upload
            s3_key: Original S3 key for the PDF file  
            metadata: Optional metadata from marker processing
            
        Returns:
            bool: True if upload successful, False otherwise
        """
        try:
            # Extract filename from S3 key and create timestamped output path
            original_filename = s3_key.split('/')[-1]  # Get filename from S3 key
            base_name = original_filename.rsplit('.', 1)[0]  # Remove .pdf extension
            output_key = f"doc-reader-outputs/{self.processing_timestamp}/{base_name}-{self.processing_timestamp}.md"
            
            # Prepare metadata for S3 object
            s3_metadata = {
                'processing-timestamp': self.processing_timestamp,
                'original-s3-key': s3_key,
                'original-filename': original_filename,
                'content-type': 'text/markdown'
            }
            
            if metadata:
                # Add marker metadata if available (convert to strings)
                for key, value in metadata.items():
                    if isinstance(value, (str, int, float)):
                        s3_metadata[f'marker-{key}'] = str(value)
            
            # Determine output bucket - extract from output_s3_uri_prefix
            if '/' in self.output_s3_uri_prefix:
                output_bucket = self.output_s3_uri_prefix.split('/', 1)[0]
            else:
                output_bucket = self.output_s3_uri_prefix
            
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
        self.log_structured('INFO', 'Document processing started (in-memory mode)')
        
        try:
            # Step 1: Validate environment and initialize clients
            if not self.validate_environment():
                return False
            
            # Step 2: List PDF objects in S3
            pdf_objects = self.list_pdf_objects_in_s3()
            if not pdf_objects:
                self.log_structured('ERROR', 'No PDF files found to process')
                return False
            
            # Step 3: Process each PDF file in memory
            self.log_structured('INFO', 'Starting in-memory PDF processing', 
                              pdf_count=len(pdf_objects))
            
            for pdf_obj in pdf_objects:
                s3_key = pdf_obj['Key']
                
                # Process PDF directly from S3 to markdown
                result = self.download_and_process_pdf(s3_key)
                
                if result:
                    markdown_content, metadata = result
                    
                    # Upload markdown to S3
                    self.upload_markdown_to_s3(
                        markdown_content, 
                        s3_key, 
                        metadata
                    )
            
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