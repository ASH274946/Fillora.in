# Fillora Backend API - Azure App Service

## Overview

Backend API for Fillora using Azure App Service, providing REST endpoints for:
- User profile management
- Form data storage and retrieval
- Document processing orchestration
- Analytics and statistics

## Architecture

```
Backend/
├── api/                    # API endpoints
│   ├── auth/              # Authentication endpoints
│   ├── profiles/          # User profile management
│   ├── forms/             # Form data endpoints
│   ├── documents/         # Document upload/processing
│   └── analytics/         # Analytics endpoints
├── services/              # Business logic
│   ├── azure_services.js  # Azure service integrations
│   ├── profile_service.js # Profile management
│   └── form_service.js    # Form processing
├── config/                # Configuration
│   └── azure_config.js    # Azure resource configuration
└── package.json           # Node.js dependencies
```

## Tech Stack

- **Runtime**: Node.js (Azure App Service)
- **Framework**: Express.js
- **Database**: Azure SQL Database / Cosmos DB
- **Storage**: Azure Blob Storage
- **Authentication**: Azure AD B2C
- **AI Services**: 
  - Azure OpenAI
  - Azure Form Recognizer
  - Azure Computer Vision

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `POST /api/auth/refresh` - Refresh token

### Profiles
- `GET /api/profiles/:userId` - Get user profile
- `PUT /api/profiles/:userId` - Update user profile
- `GET /api/profiles/:userId/autofill-data` - Get autofill data

### Forms
- `GET /api/forms` - List user forms
- `POST /api/forms` - Create new form
- `GET /api/forms/:formId` - Get form details
- `PUT /api/forms/:formId` - Update form
- `DELETE /api/forms/:formId` - Delete form

### Documents
- `POST /api/documents/upload` - Upload document
- `POST /api/documents/:documentId/analyze` - Analyze document
- `GET /api/documents/:documentId/extract` - Get extracted fields

### Analytics
- `GET /api/analytics/dashboard` - Dashboard statistics
- `GET /api/analytics/usage` - Usage statistics

## Setup

1. Create Azure App Service
2. Configure environment variables
3. Deploy code
4. Set up database connections
5. Configure Azure AD B2C

## Environment Variables

```env
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_API_KEY=
AZURE_SPEECH_ENDPOINT=
AZURE_SPEECH_API_KEY=
AZURE_VISION_ENDPOINT=
AZURE_VISION_API_KEY=
AZURE_FORM_RECOGNIZER_ENDPOINT=
AZURE_FORM_RECOGNIZER_API_KEY=
AZURE_STORAGE_CONNECTION_STRING=
AZURE_SQL_CONNECTION_STRING=
AZURE_AD_B2C_TENANT_ID=
AZURE_AD_B2C_CLIENT_ID=
```

## Deployment

Deploy to Azure App Service using:
- Azure CLI
- Visual Studio Code Azure extension
- GitHub Actions
- Azure DevOps

## Status

**Status**: 🚧 Structure created, implementation pending

This is a placeholder structure. Full implementation required for production.
