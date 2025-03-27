# PDF Generation Server

A Node.js server for generating PDF resumes from HTML templates using Puppeteer.

## Requirements

- Node.js (v16+)
- PM2 (for production deployment)
- Git (for deployment updates)

## Setup

1. Clone this repository
2. Install dependencies:
   ```
   npm install
   ```
3. Install PM2 globally if not already installed:
   ```
   npm install -g pm2
   ```

## Development

Start the server locally:

```
node server.js
```

## Production Deployment

Use the deployment script to manage the server:

```
# Install dependencies
./deploy.sh setup

# Start server with PM2
./deploy.sh start

# Check server status
./deploy.sh status

# Restart server
./deploy.sh restart

# Stop server
./deploy.sh stop

# Update from git and restart
./deploy.sh update
```

## API Endpoints

### Health Check
```
GET /health
```

### Generate PDF
```
POST /generate-pdf
```

Body:
```json
{
  "resumeData": {
    "content": "# John Doe\n## Professional Experience\n- Full Stack Developer at XYZ Corp",
    "keywords": ["JavaScript", "React", "Node.js"],
    "template": {
      "id": "professional",
      "name": "Professional",
      "colors": {
        "primary": "#34495e",
        "secondary": "#7f8c8d",
        "accent": "#2980b9",
        "background": "#f8f9fa",
        "text": "#333333"
      },
      "fontFamily": "Times-Roman",
      "spacing": {
        "sectionMargin": 15,
        "itemMargin": 8
      },
      "layout": "standard"
    }
  },
  "templateId": "professional"
}
```

## Server Configuration

Edit the `.env` file to configure server settings:

```
PORT=80
```
