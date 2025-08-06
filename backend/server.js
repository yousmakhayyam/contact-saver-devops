const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.WEBSITES_PORT || process.env.PORT || 80;

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

// Simple in-app quotes DB
const quotes = {
  happy: ["Happiness is a direction, not a place.", "Smile, it's free therapy!", "Every day may not be good, but there’s something good in every day."],
  sad: ["Tears are words the heart can’t express.", "It's okay to feel sad sometimes.", "Out of difficulties grow miracles."],
  angry: ["Don't let anger control you.", "Breathe in calm, breathe out fire.", "Speak when you are angry and you’ll make the best speech you’ll ever regret."],
  chill: ["Take it easy. Life is short.", "Relax. Recharge. Reflect.", "Peace begins with a smile."],
  romantic: ["Love is composed of a single soul inhabiting two bodies.", "You are my today and all of my tomorrows.", "Every love story is beautiful, but ours is my favorite."]
};

// API to get quote based on mood
app.get('/api/quote/:mood', (req, res) => {
  const mood = req.params.mood.toLowerCase();
  const moodQuotes = quotes[mood];
  if (moodQuotes) {
    const randomQuote = moodQuotes[Math.floor(Math.random() * moodQuotes.length)];
    res.json({ quote: randomQuote });
  } else {
    res.status(404).json({ error: 'Mood not found 😔' });
  }
});

app.listen(PORT, () => {
  console.log(`🌈 Moodly running on http://localhost:${PORT}`);
});
