// PM2 Ecosystem Config for NestJS Application
// ================================================
//
// NestJS compiles TypeScript to JavaScript in the dist/ folder.
// The entry point is dist/main.js by default.
//
// Usage:
//   1. Build first:  npm run build
//   2. Copy to your project root: cp ecosystem-nestjs.config.js ecosystem.config.js
//   3. Edit the values below
//   4. mkdir logs
//   5. Start:  pm2 start ecosystem.config.js
//   6. Save:   pm2 save && pm2 startup
//
// Build & Deploy flow:
//   npm install
//   npm run build                          Compiles TS → dist/
//   pm2 restart yourapp --update-env
//
// ================================================

module.exports = {
  apps: [
    {
      // App identity
      name: 'yourapp-api',
      script: 'dist/main.js',              // NestJS compiled entry point
      cwd: '/var/www/apps/yourapp',

      // Cluster mode — NestJS supports this
      instances: 'max',                     // 'max' for all CPU cores
      exec_mode: 'cluster',

      // Environment
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },

      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3001,
      },

      // Auto-restart
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',

      // Restart strategy
      exp_backoff_restart_delay: 100,

      // Logs
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      time: true,

      // Graceful shutdown — important for NestJS
      // NestJS has lifecycle hooks (onModuleDestroy, beforeApplicationShutdown)
      // Give it enough time to close DB connections, finish requests, etc.
      kill_timeout: 10000,                  // 10s for graceful shutdown
      listen_timeout: 10000,

      // Shutdown signal — NestJS listens for SIGINT by default
      // Make sure app.enableShutdownHooks() is called in main.ts
      shutdown_with_message: false,
    },
  ],
};

// ================================================
// NestJS main.ts — Recommended Production Setup
// ================================================
//
// import { NestFactory } from '@nestjs/core';
// import { AppModule } from './app.module';
//
// async function bootstrap() {
//   const app = await NestFactory.create(AppModule);
//
//   // Enable graceful shutdown hooks (for PM2 reload/restart)
//   app.enableShutdownHooks();
//
//   // Enable CORS (if needed)
//   app.enableCors({
//     origin: ['https://yourdomain.com'],
//     credentials: true,
//   });
//
//   // Global prefix (optional)
//   app.setGlobalPrefix('api');
//
//   const port = process.env.PORT || 3000;
//   await app.listen(port, '0.0.0.0');
//   console.log(`Application running on port ${port}`);
// }
// bootstrap();
//
// ================================================
// Multiple NestJS Services (Microservices)
// ================================================
//
// If running multiple NestJS services on the same VPS:
//
// module.exports = {
//   apps: [
//     {
//       name: 'api-gateway',
//       script: 'dist/main.js',
//       cwd: '/var/www/apps/api-gateway',
//       env: { PORT: 3000 },
//     },
//     {
//       name: 'auth-service',
//       script: 'dist/main.js',
//       cwd: '/var/www/apps/auth-service',
//       env: { PORT: 3001 },
//     },
//     {
//       name: 'notification-service',
//       script: 'dist/main.js',
//       cwd: '/var/www/apps/notification-service',
//       env: { PORT: 3002 },
//     },
//   ],
// };
//
// ================================================
