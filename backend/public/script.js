function setMood(mood) {
  fetch(`/api/quote/${mood}`)
    .then(res => res.json())
    .then(data => {
      document.getElementById('quote').textContent = data.quote || "Couldn't load quote!";
      document.getElementById('emoji').textContent = getEmoji(mood);
      changeTheme(mood);
    });
}

function getEmoji(mood) {
  const emojis = {
    happy: "😊",
    sad: "😢",
    angry: "😡",
    chill: "😌",
    romantic: "😍"
  };
  return emojis[mood] || "✨";
}

function changeTheme(mood) {
  const root = document.documentElement;
  const themes = {
    happy: "linear-gradient(to right, #ffecd2, #fcb69f)",
    sad: "linear-gradient(to right, #a1c4fd, #c2e9fb)",
    angry: "linear-gradient(to right, #f857a6, #ff5858)",
    chill: "linear-gradient(to right, #a8edea, #fed6e3)",
    romantic: "linear-gradient(to right, #fbc2eb, #a6c1ee)"
  };
  root.style.setProperty('--bg', themes[mood] || themes['happy']);
}
