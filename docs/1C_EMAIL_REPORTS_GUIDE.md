# 1C Integration Email Reports Configuration Guide

## Overview

The 1C Notify Update API (`/api/1c_notify_update`) now includes automatic email reporting functionality that sends detailed reports to administrators about every synchronization request, whether successful or failed.

## Features

### 📧 Automatic Email Reports
- **Error Reports**: Sent for every failed synchronization attempt
- **Success Reports**: Optional reports for successful synchronization (disabled by default)
- **Detailed Statistics**: Processing time, items processed, HTTP requests, performance metrics
- **Log Excerpts**: Last 20 lines from the 1C integration log
- **Professional HTML Templates**: Styled email templates with clear visual indicators

### 🎯 Report Types

#### 1. Error Reports (Always Sent)
- **Conflict Errors**: When synchronization is already running
- **Critical Thread Errors**: Unexpected exceptions in main processing thread
- **Process Errors**: Synchronization completed but with errors
- **General Errors**: Thread initialization or other system errors

#### 2. Success Reports (Optional)
- **Complete Statistics**: Items processed, HTTP requests, duration
- **Performance Metrics**: Processing speed, average response times
- **Warnings**: Non-critical issues that occurred during processing
- **Validation Confirmation**: All data synchronized successfully

## Configuration

### Required Environment Variables

```bash
# Administrator email address (REQUIRED)
export ADMIN_EMAIL="admin@yourcompany.com"
```

### Optional Environment Variables

```bash
# Disable all email reports (emergency switch)
export DISABLE_1C_EMAIL_REPORTS="true"  # Default: false

# Enable success reports (usually only errors are sent)
export SEND_1C_SUCCESS_REPORTS="true"   # Default: false
```

### Email Delivery Configuration

The system uses the existing Padrino mailer configuration. Ensure you have:

```ruby
# In app.rb or configuration
set :delivery_method, :sendmail  # or :smtp
```

For SMTP configuration, see the main email setup guide.

## Email Report Structure

### Error Report Contents

1. **Header Section**
   - Critical alert styling (red)
   - Request ID for tracking
   - Timestamp and server information

2. **Error Details**
   - Error type and message
   - Error code for categorization
   - Stack trace (first 10 lines)

3. **Statistics**
   - Processing duration
   - Items processed before failure
   - HTTP requests made
   - Failed operations count

4. **Log Excerpt**
   - Last 20 lines from 1C integration log
   - Contextual information around the error

5. **Action Items**
   - Recommended troubleshooting steps
   - Server health checks
   - Contact information

### Success Report Contents

1. **Header Section**
   - Success styling (green)
   - Request ID and completion time

2. **Processing Statistics**
   - Total processing time
   - Items synchronized
   - HTTP requests to 1C
   - Batches processed

3. **Performance Metrics**
   - Items per second
   - Average HTTP response time
   - System resource usage

4. **Validation Status**
   - Data integrity confirmation
   - Synchronization completeness
   - Client-facing impact

## Request Tracking

### Unique Request IDs

Each API call generates a unique request ID in the format:
```
1C_YYYYMMDD_HHMMSS_XXXX
```

Where:
- `YYYYMMDD_HHMMSS`: Timestamp
- `XXXX`: Random 4-character hex suffix

Example: `1C_20251109_143052_a7f3`

### Request Lifecycle

1. **Request Initiated**: ID generated, start time recorded
2. **Processing**: Statistics collected (items, HTTP requests, duration)
3. **Completion**: Email sent based on result (success/error)
4. **Tracking**: All logs and emails include the request ID

## Error Categories

### HTTP 409 - Conflict
```json
{
  "message": "The process is already underway",
  "status": "error",
  "request_id": "1C_20251109_143052_a7f3"
}
```
**Email**: Sent immediately with conflict details

### HTTP 500 - Server Error
```json
{
  "message": "An error occurred: [error details]",
  "status": "error",
  "request_id": "1C_20251109_143052_a7f3"
}
```
**Email**: Sent with full error context and stack trace

### HTTP 200 - Success (with errors)
```json
{
  "message": "Operation completed successfully",
  "status": "success"
}
```
**Email**: Error report if `ok = false`, success report if `ok = true`

## Monitoring and Alerting

### Email Delivery Status

The system logs email delivery attempts:

```
[1C_EMAIL] Отправка email отчёта об ошибке: 1C_20251109_143052_a7f3
[1C_EMAIL] ✅ Email отчёт об ошибке отправлен успешно: 1C_20251109_143052_a7f3
```

Or in case of failure:
```
[1C_EMAIL] ❌ Ошибка отправки email отчёта: SMTP Connection failed
[1C_EMAIL] Получатель: admin@example.com
```

### System Health Checks

Email delivery health is checked through:
1. `ADMIN_EMAIL` environment variable validation
2. Mailer system availability
3. Asynchronous delivery success/failure logging

## Troubleshooting

### No Emails Received

1. **Check ADMIN_EMAIL**:
   ```bash
   echo $ADMIN_EMAIL
   # Should output your admin email address
   ```

2. **Check Email System**:
   ```bash
   # Test email delivery through the system
   curl -X GET https://yoursite.com/testing/email/quick
   ```

3. **Check Logs**:
   ```bash
   grep "1C_EMAIL" /path/to/your/log/1c_notify_update.log
   ```

### Email Delivery Failures

1. **SMTP Configuration**: Verify SMTP settings if using external email service
2. **Sendmail**: Ensure sendmail is installed and configured
3. **Permissions**: Check that the application can write to mail queues
4. **Firewall**: Verify outbound email ports are open

### High Email Volume

If you're receiving too many emails:

1. **Disable Success Reports**:
   ```bash
   unset SEND_1C_SUCCESS_REPORTS
   # Or explicitly set to false
   export SEND_1C_SUCCESS_REPORTS="false"
   ```

2. **Emergency Disable**:
   ```bash
   export DISABLE_1C_EMAIL_REPORTS="true"
   # Restart the application
   ```

3. **Filter by Criticality**: Set up email rules to prioritize critical errors

## Security Considerations

### Sensitive Information

- **Error Messages**: May contain technical details about your system
- **Log Excerpts**: Could include debugging information
- **Statistics**: Performance data that could be useful for attackers

### Recommendations

1. **Secure Email Transport**: Use TLS/SSL for email delivery
2. **Access Control**: Limit who receives these emails
3. **Email Retention**: Set up automatic cleanup of old email reports
4. **Monitoring**: Monitor for unusual email volume patterns

## Integration with Existing Systems

### Log Aggregation

Email reports complement existing logging:
- **Immediate Alerts**: Critical issues sent via email
- **Detailed Analysis**: Full logs available in standard log files
- **Historical Data**: Email archives provide timeline of issues

### Monitoring Tools

Integration points:
- **Request IDs**: Use for correlation across monitoring systems
- **Statistics**: Can be ingested into monitoring dashboards
- **Alerts**: Email rules can trigger additional automated responses

## Performance Impact

### Email Delivery

- **Asynchronous**: All emails sent in background threads
- **Non-blocking**: API responses are not delayed by email delivery
- **Minimal Overhead**: Statistics collection adds <1ms to processing time

### Resource Usage

- **Memory**: Minimal additional memory for statistics storage
- **CPU**: Email template rendering occurs in background
- **Network**: Additional SMTP connections for email delivery

## Testing

To test the email functionality:

1. **Force an Error**:
   ```bash
   # Make two simultaneous requests to trigger conflict
   curl -u user:pass https://yoursite.com/api/1c_notify_update &
   curl -u user:pass https://yoursite.com/api/1c_notify_update &
   ```

2. **Check Email Templates**:
   - View `app/views/mail_1c_error_report/error_report.haml`
   - View `app/views/mail_1c_error_report/success_report.haml`

3. **Monitor Logs**:
   ```bash
   tail -f log/1c_notify_update.log | grep "1C_EMAIL"
   ```

---

## Configuration Summary

```bash
# Required
export ADMIN_EMAIL="admin@yourcompany.com"

# Optional
export DISABLE_1C_EMAIL_REPORTS="false"      # true to disable all emails
export SEND_1C_SUCCESS_REPORTS="false"       # true to enable success emails

# Email system (existing configuration)
set :delivery_method, :sendmail  # or :smtp
```

## Quick Start

1. Set `ADMIN_EMAIL` environment variable
2. Restart your application
3. Make a test API call
4. Check your email for reports
5. Monitor logs for delivery confirmation

The system is designed to work out-of-the-box with minimal configuration while providing comprehensive monitoring capabilities for your 1C integration.
