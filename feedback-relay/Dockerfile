FROM node:24-alpine
ENV NODE_ENV=production HOST=0.0.0.0
WORKDIR /app
COPY --chown=node:node package.json server.mjs linear.mjs ./
USER node
EXPOSE 8080
CMD ["node", "server.mjs"]
