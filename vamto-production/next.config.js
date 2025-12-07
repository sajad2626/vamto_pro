
/** next.config.js */

module.exports = {

  reactStrictMode: true,

  swcMinify: true,

  async headers() {

    return [

      {

        source: "/(.*)",

        headers: [

          { key: "X-Frame-Options", value: "DENY" },

          { key: "X-Content-Type-Options", value: "nosniff" },

          { key: "Referrer-Policy", value: "no-referrer-when-downgrade" },

          { key: "Permissions-Policy", value: "geolocation=()" },

          { key: "Content-Security-Policy", value: "default-src 'self'; img-src 'self' data: https:; script-src 'self'; style-src 'self' 'unsafe-inline';" }

        ]

      }

    ];

  }

};

