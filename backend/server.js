const express = require('express');
const path = require('path');
const app = express();

// Serve static files from the backend directory
app.use(express.static(path.join(__dirname)));

// Serve index.html on the root route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Start the server
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 App running at http://localhost:${PORT}`);
});
