FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# ✅ Fixed to match server.js
EXPOSE 3000

CMD ["node", "server.js"]
