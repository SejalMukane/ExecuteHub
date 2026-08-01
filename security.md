# QualityHub Security

This document outlines the security model, practices, and controls implemented in QualityHub.

## Overview

Security is critical for a platform that connects to source code repositories, executes arbitrary browser tests, and stores sensitive artifacts. QualityHub applies defense-in-depth across authentication, authorization, isolation, secrets management, and data protection.

## Authentication

### User Authentication

- Users authenticate with email and password using Devise
- Passwords are hashed with bcrypt
- JWT tokens are used for API authentication
- Sessions expire after a configurable period of inactivity
- Multi-factor authentication (MFA) is supported via TOTP

### GitHub Authentication

- GitHub OAuth is used for repository connection
- Access tokens are encrypted at rest
- Tokens have minimal required scopes
- Token rotation is supported

## Authorization

### Role-Based Access Control (RBAC)

| Role | Permissions |
| --- | --- |
| Admin | Full access to team, projects, users, and billing |
| Developer | Create test runs, view results, debug failures |
| QA | Trigger runs, manage test configurations, view reports |
| Viewer | Read-only access to dashboards and reports |

### Project-Level Access

- Users can only access projects they are members of
- All API endpoints enforce project-scoped authorization
- Sensitive actions require explicit role checks

## Webhook Security

### GitHub Webhooks

- GitHub webhook signatures are verified using the configured secret
- Payloads are rejected if signatures do not match
- Webhook timestamps are checked to prevent replay attacks
- IPs can be restricted to GitHub webhook IP ranges

### Jenkins Webhooks

- Jenkins callbacks require authentication tokens
- Tokens are rotated periodically

## Test Execution Isolation

### Container Isolation

- Each test run executes in a dedicated Docker container
- Workers run with minimal privileges
- Containers do not share network namespaces
- Root filesystem is read-only where possible

### Browser Isolation

- Each test uses a fresh browser context
- Cookies, local storage, and cache are cleared between tests
- Browser processes run inside the container sandbox

### Network Isolation

- Worker pods are restricted by Kubernetes NetworkPolicy
- Workers can only access the internet, S3, and Redis
- Internal services are not reachable from workers

## Secrets Management

### Types of Secrets

- Database credentials
- Redis credentials
- AWS credentials
- GitHub access tokens
- JWT signing keys
- Webhook secrets

### Storage

- Production secrets are stored in AWS Secrets Manager
- Development secrets are managed through environment variables
- Secrets are never committed to source control
- Secrets are injected into containers at runtime

### Encryption

- Data at rest is encrypted using AWS-managed keys
- Data in transit uses TLS 1.2 or higher
- Database connections use SSL
- Artifact URLs are pre-signed and time-limited

## Data Protection

### Personal Data

- User emails and names are stored securely
- Data retention policies comply with team settings
- Users can request data export or deletion

### Artifacts

- Videos, screenshots, and logs may contain sensitive application data
- Artifact access is restricted to project members
- S3 buckets are private by default
- Pre-signed URLs expire after a short time

## API Security

### Rate Limiting

- Authenticated users: 1,000 requests per minute
- Unauthenticated users: 60 requests per minute
- Rate limits are enforced per user or IP

### Input Validation

- All API inputs are validated using strong schemas
- SQL injection is prevented through ActiveRecord parameterized queries
- XSS protection is enforced by escaping output

### CORS

- CORS is configured to allow only the known dashboard origin
- Wildcard origins are not allowed in production

## Audit Logging

The platform logs security-relevant events:

- User login and logout
- Project creation and deletion
- Test run triggers
- GitHub connection and disconnection
- Role changes
- Failed authentication attempts
- Webhook deliveries

Logs are retained according to the team policy and can be forwarded to a SIEM.

## Dependency Security

- Dependencies are scanned for known vulnerabilities
- Automated security updates are applied where safe
- Gemfile and package lock files are committed and reviewed

## Incident Response

### Security Incident Types

- Unauthorized access
- Data exposure
- Malicious test code
- Credential leak
- Denial of service

### Response Steps

1. Identify and contain the incident
2. Revoke compromised credentials
3. Notify affected users
4. Document findings and remediation
5. Update security controls based on lessons learned

## Compliance Considerations

- SOC 2 readiness recommendations
- GDPR data handling support
- Data residency configuration options
- Audit trails for compliance reviews

## Security Checklist

- [ ] Authentication with strong password policies
- [ ] RBAC implemented and enforced
- [ ] GitHub webhooks signature verified
- [ ] Workers run in isolated containers
- [ ] Secrets stored in AWS Secrets Manager
- [ ] TLS enforced for all traffic
- [ ] S3 buckets private with pre-signed URLs
- [ ] Rate limiting enabled
- [ ] Input validation on all endpoints
- [ ] Audit logging configured
- [ ] Dependency scanning in CI/CD
- [ ] Security incident response plan documented
