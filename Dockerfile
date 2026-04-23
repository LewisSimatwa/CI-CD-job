FROM node:18-alpine
WORKDIR /app
COPY app/package*.json ./
RUN npm install --production
COPY app/ .
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget -qO- http://localhost:3000/health || exit 1
USER node
CMD ["node", "index.js"]