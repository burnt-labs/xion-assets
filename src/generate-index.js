const fs = require('fs');
const path = require('path');

// Base directory containing JSON files
const baseDir = '.';

// Output file
const outputFile = 'index.html';

// Helper function to recursively list all JSON files
function getJsonFiles(dir, basePath = '') {
  const files = fs.readdirSync(dir, { withFileTypes: true });
  let fileList = [];

  files.forEach((file) => {
    const relativePath = path.join(basePath, file.name);
    const fullPath = path.join(dir, file.name);

    if (file.isDirectory()) {
      fileList = fileList.concat(getJsonFiles(fullPath, relativePath));
    } else if (file.isFile() && file.name.endsWith('.json') && ! file.name.endsWith('schema.json')) {
      fileList.push(relativePath);
    }
  });

  return fileList;
}

// Generate index.html content
function generateIndexHtml(files) {
  const links = files
    .map(
      (file) =>
        `<li><a href="/${file.replace(/ /g, '%20')}">${file}</a></li>`
    )
    .join('\n');

  return `
<!DOCTYPE html>
<html>
<head>
  <title>JSON API</title>
</head>
<body>
  <h1>Available JSON Files</h1>
  <ul>
    ${links}
  </ul>
</body>
</html>
  `;
}

// Main logic
try {
  const jsonFiles = getJsonFiles(baseDir);
  const htmlContent = generateIndexHtml(jsonFiles);

  // Write the index.html file
  fs.writeFileSync(outputFile, htmlContent);
  console.log(`Index file generated: ${outputFile}`);
} catch (error) {
  console.error('Error generating index file:', error);
}
