const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const helmet = require('helmet');
const morgan = require('morgan');
const puppeteer = require('puppeteer');
const fs = require('fs-extra');
const path = require('path');
require('dotenv').config();

// Create Express app
const app = express();
// Always use port 3000 regardless of environment variable
const PORT = 3000;

// Apply middleware
app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(helmet({
  contentSecurityPolicy: false, // Disable for puppeteer rendering
}));
app.use(morgan('combined'));

// Ensure temp directory exists
const tempDir = path.join(__dirname, 'temp');
fs.ensureDirSync(tempDir);

// Simple health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'PDF generation server is running' });
});

// PDF generation endpoint
app.post('/generate-pdf', async (req, res) => {
  // ... keep existing code (PDF generation functionality)
});

// Function to generate HTML for the resume
function generateResumeHTML(resumeData) {
  // ... keep existing code (HTML generation functionality)
}

// Start the server
app.listen(PORT, () => {
  console.log(`PDF generation server running on port ${PORT}`);
  console.log(`NOTE: This server is designed to run behind Nginx reverse proxy`);
});
