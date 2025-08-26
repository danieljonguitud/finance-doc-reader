# Auth Services

AWS Cognito-based authentication service for the Finance Document Reader application.

## Overview

This service provides user authentication and management using AWS Cognito User Pools. It includes:

- **User Pool**: Manages user registration, authentication, and profile data
- **User Pool Client**: Web application client for frontend integration

## Resources Created

- `AWS::Cognito::UserPool`: Main user pool with email-based authentication
- `AWS::Cognito::UserPoolClient`: Web client configuration
- `AWS::Logs::LogGroup`: CloudWatch logs for debugging

## Configuration

### User Pool Features

- **Authentication**: Email/username with secure password requirements
- **Verification**: Email verification required for new accounts
- **Security**: Advanced security features enabled with breach protection
- **Attributes**: Email, given_name, family_name required fields
- **Recovery**: Email-based account recovery

### Password Policy

- Minimum 8 characters
- Requires uppercase, lowercase, numbers, and symbols
- Temporary passwords valid for 7 days

## Deployment

### Prerequisites

- AWS CLI configured with appropriate permissions
- SAM CLI installed
- Access to deploy Cognito resources

### Deploy the Stack

```bash
cd auth-services

# First-time deployment with guided setup
sam deploy --guided

# Subsequent deployments
sam deploy
```

### Configuration Parameters

- `ProjectName`: Base name for all resources (default: `finance-doc-auth-services`)

## Integration

### Exported Values

The following values are exported for use in other stacks:

- `{ProjectName}-user-pool-id`: Cognito User Pool ID
- `{ProjectName}-user-pool-arn`: Cognito User Pool ARN
- `{ProjectName}-user-pool-client-id`: Web client ID
- `{ProjectName}-user-pool-provider-name`: Provider name for API Gateway integration
- `{ProjectName}-user-pool-provider-url`: Provider URL for JWT validation

### Database Integration

The User Pool is configured to work with the existing `users` table in your PostgreSQL database:

- Users will need to be synced between Cognito and the database
- The `cognito_sub` field in the users table stores the Cognito user identifier
- Consider implementing Lambda triggers for automatic user synchronization

### API Gateway Integration

To integrate with your existing `web-api`:

1. Update API Gateway methods to use Cognito authorizers
2. Reference the exported User Pool ARN in your web-api template
3. Configure JWT token validation

## Testing

### AWS Console

1. Navigate to AWS Cognito in the console
2. Find your user pool
3. Test user registration and authentication flows
4. Monitor CloudWatch logs for debugging

### CLI Testing

```bash
# Create a test user
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id <USER_POOL_ID> \
  --username testuser@example.com \
  --password NewPass123! \
  --permanent
```

## Next Steps

1. **Lambda Triggers**: Add pre/post authentication triggers for database sync
2. **Frontend Integration**: Implement client-side authentication using the User Pool Client
3. **API Authorization**: Update web-api to use Cognito JWT tokens
4. **User Management**: Create Lambda functions for user CRUD operations
5. **Hosted UI**: Configure Cognito Hosted UI for quick frontend integration

## Monitoring

- CloudWatch Logs: `/aws/cognito/finance-doc-auth-services`
- Cognito Console: Monitor user activity and security events
- API Gateway Logs: Track authentication failures and successes