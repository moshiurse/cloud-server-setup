// PM2 Ecosystem Config for Node.js Application
// ================================================
//
// Works with: Express, Fastify, Koa, Hapi, or any Node.js server
//
// Usage:
//   1. Copy to your project root: cp ecosystem-nodejs.config.js ecosystem.config.js
//   2. Edit the values below (name, script, port, etc.)
//   3. Start:  pm2 start ecosystem.config.js
//   4. Save:   pm2 save
//   5. Startup: pm2 startup  (follow the printed command)
//
// Commands:
//   pm2 start ecosystem.config.js     Start the app
//   pm2 restart yourapp               Restart
//   pm2 reload yourapp                Zero-downtime reload (cluster mode)
//   pm2 stop yourapp                  Stop
//   pm2 delete yourapp                Remove from PM2
//   pm2 logs yourapp                  View logs
//   pm2 monit                         Monitor all apps
//
// ================================================

module.exports = {
  apps: [
    {
      // App identity
      name: 'yourapp',
      script: 'app.js',                    // Entry file: app.js, server.js, index.js, dist/main.js
      cwd: '/var/www/apps/yourapp',

      // Cluster mode — use all CPU cores for maximum performance
      instances: 'max',                     // 'max' = all cores, or set a number: 2, 4
      exec_mode: 'cluster',                 // 'cluster' for multi-core, 'fork' for single process

      // Environment
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },

      // Separate environment for staging (use: pm2 start ecosystem.config.js --env staging)
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3001,
      },

      // Auto-restart on crash
      autorestart: true,
      watch: false,                         // Don't watch files in production
      max_memory_restart: '500M',           // Restart if memory exceeds this

      // Restart strategy — exponential backoff on repeated crashes
      exp_backoff_restart_delay: 100,

      // Logs
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,                     // Merge logs from all cluster instances

      // Graceful shutdown
      kill_timeout: 5000,                   // Wait 5s for graceful shutdown
      listen_timeout: 10000,                // Wait 10s for app to be ready

      // Time prefix in logs
      time: true,
    },
  ],
};
