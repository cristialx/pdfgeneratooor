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
const PORT = process.env.PORT || 80;

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
  console.log('PDF generation request received');
  
  try {
    const { resumeData, templateId } = req.body;
    
    if (!resumeData || !templateId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    console.log(`Generating PDF for template: ${templateId}`);
    
    // Generate HTML based on template and data
    const html = generateResumeHTML(resumeData);
    
    // Launch puppeteer
    const browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const page = await browser.newPage();
    
    // Set content and wait for rendering
    await page.setContent(html, { waitUntil: 'networkidle0' });
    
    // Generate PDF
    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: {
        top: '20px',
        right: '20px',
        bottom: '20px',
        left: '20px'
      }
    });
    
    await browser.close();
    
    // Send PDF as response
    res.contentType('application/pdf');
    res.send(pdfBuffer);
    
    console.log('PDF generated and sent successfully');
    
  } catch (error) {
    console.error('Error generating PDF:', error);
    res.status(500).json({ 
      error: 'Failed to generate PDF', 
      message: error.message
    });
  }
});

// Function to generate HTML for the resume
function generateResumeHTML(resumeData) {
  const template = resumeData.template;
  
  // Helper function to get spacing values based on template
  const getSpacing = (template) => {
    const layout = template?.layout || 'standard';
    const customSpacing = template?.spacing || {};
    
    const spacingDefaults = {
      standard: { sectionMargin: 20, itemMargin: 10 },
      compact: { sectionMargin: 15, itemMargin: 5 },
      spacious: { sectionMargin: 25, itemMargin: 15 }
    };
    
    const defaultSpacing = spacingDefaults[layout] || spacingDefaults.standard;
    
    return {
      sectionMargin: customSpacing.sectionMargin || defaultSpacing.sectionMargin,
      itemMargin: customSpacing.itemMargin || defaultSpacing.itemMargin
    };
  };

  const spacing = getSpacing(template);
  
  // Parse markdown to HTML
  const parseMarkdown = (content) => {
    if (!content) return '';
    
    return content
      .replace(/^# (.*$)/gm, '<h1>$1</h1>')
      .replace(/^## (.*$)/gm, '<h2>$1</h2>')
      .replace(/^### (.*$)/gm, '<h3>$1</h3>')
      .replace(/^\* (.*$)/gm, '<li>$1</li>')
      .replace(/^- (.*$)/gm, '<li>$1</li>')
      .replace(/\n\n/g, '<br/><br/>');
  };
  
  // Generate the HTML
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Resume</title>
      <style>
        body {
          font-family: ${template.fontFamily || 'Arial, sans-serif'};
          color: ${template.colors.text};
          background-color: ${template.colors.background};
          margin: 0;
          padding: 20px;
        }
        .container {
          max-width: 800px;
          margin: 0 auto;
          padding: 30px;
          border-top: 6px solid ${template.colors.primary};
        }
        h1 {
          color: ${template.colors.primary};
          font-size: 24px;
          margin-bottom: ${spacing.itemMargin * 2}px;
        }
        h2 {
          color: ${template.colors.secondary};
          font-size: 18px;
          margin-bottom: ${spacing.itemMargin}px;
          border-bottom: 1px solid #eee;
          padding-bottom: 5px;
        }
        h3 {
          font-size: 16px;
          margin-bottom: ${spacing.itemMargin / 2}px;
        }
        p {
          margin-bottom: ${spacing.itemMargin}px;
        }
        ul {
          margin-bottom: ${spacing.itemMargin}px;
        }
        li {
          margin-bottom: ${spacing.itemMargin / 2}px;
        }
        .keywords {
          margin-top: ${spacing.sectionMargin}px;
        }
        .keyword {
          display: inline-block;
          background-color: ${template.colors.accent}20;
          color: ${template.colors.accent};
          border: 1px solid ${template.colors.accent}40;
          border-radius: 4px;
          padding: 4px 8px;
          margin-right: 8px;
          margin-bottom: 8px;
          font-size: 12px;
        }
        ${template.layout === 'sidebar' ? `
          .resume-content {
            display: flex;
          }
          .main-content {
            flex: 2;
            padding-right: 20px;
          }
          .sidebar {
            flex: 1;
            border-left: 1px solid #eee;
            padding-left: 20px;
          }
        ` : ''}
      </style>
    </head>
    <body>
      <div class="container">
        ${template.layout === 'sidebar' 
          ? `<div class="resume-content">
              <div class="main-content">
                ${parseMarkdown(resumeData.content)}
              </div>
              <div class="sidebar">
                <h2>Key Skills</h2>
                <div class="keywords">
                  ${resumeData.keywords.map((keyword) => 
                    `<span class="keyword">${keyword}</span>`
                  ).join('')}
                </div>
              </div>
            </div>`
          : `<div>
              ${parseMarkdown(resumeData.content)}
              <div class="keywords">
                <h2>Key Skills</h2>
                ${resumeData.keywords.map((keyword) => 
                  `<span class="keyword">${keyword}</span>`
                ).join('')}
              </div>
            </div>`
        }
      </div>
    </body>
    </html>
  `;
  
  return html;
}

// Start the server
app.listen(PORT, () => {
  console.log(`PDF generation server running on port ${PORT}`);
});
