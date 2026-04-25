// PM2 Ecosystem Config for Next.js Application
// ================================================
//
// Next.js runs its own built-in server, so the script points to
// the Next.js binary with the "start" argument.
//
// Usage:
//   1. Build first:  npm run build
//   2. Copy to your project root: cp ecosystem-nextjs.config.js ecosystem.config.js
//   3. Edit the values below (name, port, cwd)
//   4. mkdir logs
//   5. Start:  pm2 start ecosystem.config.js
//   6. Save:   pm2 save && pm2 startup
//
// Important:
//   - Next.js must be built before starting (npm run build)
//   - Next.js does NOT support cluster mode (it handles this internally)
//   - Use 'fork' exec_mode (not 'cluster')
//   - If you need multiple instances, run on different ports and load balance via Nginx
//
// ================================================

module.exports = {
  apps: [
    {
      // App identity
      name: 'yourapp',
      script: 'node_modules/next/dist/bin/next',
      args: 'start',
      cwd: '/var/www/apps/yourapp',

      // Next.js manages its own workers — use fork mode
      instances: 1,
      exec_mode: 'fork',

      // Environment
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
        // HOSTNAME: '0.0.0.0',            // Uncomment if Next.js only binds to localhost
      },

      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3001,
      },

      // Auto-restart
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',

      // Restart strategy
      exp_backoff_restart_delay: 100,

      // Logs
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      time: true,

      // Graceful shutdown
      kill_timeout: 5000,
      listen_timeout: 15000,               // Next.js can take longer to start
    },
  ],
};

// ================================================
// ALTERNATIVE: Next.js Standalone Mode (Recommended for production)
// ================================================
//
// If you enable "output: 'standalone'" in next.config.js:
//
//   // next.config.js
//   module.exports = {
//     output: 'standalone',
//   };
//
// Then the build produces a self-contained server at .next/standalone/server.js
// This is smaller and faster than the default mode.
//
// Use this PM2 config instead:
//
//   {
//     name: 'yourapp',
//     script: '.next/standalone/server.js',
//     cwd: '/var/www/apps/yourapp',
//     instances: 1,
//     exec_mode: 'fork',
//     env: {
//       NODE_ENV: 'production',
//       PORT: 3000,
//       HOSTNAME: '0.0.0.0',
//     },
//   }
//
// After build, copy static files:
//   cp -r .next/static .next/standalone/.next/static
//   cp -r public .next/standalone/public
//
// ================================================
