const express = require('express');
const bodyParser = require('body-parser');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());

app.post('/api/contact', (req, res) => {
  const { name, email, message } = req.body;
  const apiKey = process.env.EMAIL_API_KEY;

  // Log data and simulate saving or sending
  console.log('New message:', { name, email, message, apiKey });

  res.json({ status: 'success', msg: 'Message received! Thank you.' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
