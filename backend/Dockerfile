FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000  # ✅ Fixed to match server.js

CMD ["node", "server.js"]
