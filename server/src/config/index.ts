import 'dotenv/config';
import convict from 'convict';

export const MINIMUM_JWT_SECRET_LENGTH = 32;
export const INSECURE_JWT_SECRETS = new Set([
  'kiwishare_super_secret_key_123_abc'
]);

convict.addFormat({
  name: 'jwt-secret',
  validate: (val: any) => {
    if (typeof val !== 'string') {
      throw new Error('JWT_SECRET must be a string.');
    }
    const trimmed = val.trim();
    if (trimmed.length < MINIMUM_JWT_SECRET_LENGTH || INSECURE_JWT_SECRETS.has(trimmed)) {
      throw new Error(
        `JWT_SECRET must be set to a non-placeholder secret of at least ${MINIMUM_JWT_SECRET_LENGTH} characters.`
      );
    }
  }
});

export interface ConfigSchema {
  env: 'development' | 'production' | 'test';
  port: number;
  host: string;
  mongodb: {
    uri: string;
    uriTest: string;
  };
  jwt: {
    secret: string;
    expiresIn: string;
  };
  r2: {
    accountId: string;
    bucket: string;
    endpoint: string;
    accessKeyId: string;
    secretAccessKey: string;
    publicUrl: string;
  };
  resend: {
    apiKey: string;
    from: string;
  };
  smtp: {
    host: string;
    port: number;
    secure: boolean;
    user: string;
    pass: string;
    from: string;
  };
  chat: {
    blockedTerms: string;
  };
  platformFeeRate: number;
  earlyBirdFeeWaiver: boolean;
  stripe: {
    secretKey: string;
    publishableKey: string;
    webhookSecret: string;
  };
}

export const config = convict<ConfigSchema>({
  env: {
    doc: 'The application environment.',
    format: ['production', 'development', 'test'],
    default: 'development',
    env: 'NODE_ENV'
  },
  port: {
    doc: 'The port to bind the server to.',
    format: 'port',
    default: 3000,
    env: 'PORT'
  },
  host: {
    doc: 'The host IP to bind the server to.',
    format: String,
    default: '0.0.0.0',
    env: 'HOST'
  },
  mongodb: {
    uri: {
      doc: 'MongoDB connection URI for development/production.',
      format: String,
      default: 'mongodb://REDACTED@/kiwishare',
      env: 'MONGODB_URI'
    },
    uriTest: {
      doc: 'MongoDB connection URI for test environment.',
      format: String,
      default: 'mongodb://REDACTED@/kiwishare_test',
      env: 'MONGODB_URI_TEST'
    }
  },
  jwt: {
    secret: {
      doc: 'Secret signing key for JWT session tokens (at least 32 characters).',
      format: 'jwt-secret',
      default: 'kiwishare-dev-jwt-secret-key-2026-safe-and-secure',
      env: 'JWT_SECRET',
      sensitive: true
    },
    expiresIn: {
      doc: 'JWT token validity duration (e.g. 30d for 1 month).',
      format: String,
      default: '30d',
      env: 'JWT_EXPIRES_IN'
    }
  },
  r2: {
    accountId: {
      doc: 'Cloudflare R2 Account ID.',
      format: String,
      default: 'cdc04de9bc4c6a41b5003758e505a0d1',
      env: 'R2_ACCOUNT_ID'
    },
    bucket: {
      doc: 'Cloudflare R2 Storage Bucket name.',
      format: String,
      default: 'kiwishare',
      env: 'R2_BUCKET'
    },
    endpoint: {
      doc: 'Cloudflare R2 S3 Endpoint.',
      format: String,
      default: 'https://cdc04de9bc4c6a41b5003758e505a0d1.r2.cloudflarestorage.com',
      env: 'R2_ENDPOINT'
    },
    accessKeyId: {
      doc: 'Cloudflare R2 Access Key ID.',
      format: String,
      default: '',
      env: 'R2_ACCESS_KEY_ID'
    },
    secretAccessKey: {
      doc: 'Cloudflare R2 Secret Access Key.',
      format: String,
      default: '',
      env: 'R2_SECRET_ACCESS_KEY',
      sensitive: true
    },
    publicUrl: {
      doc: 'Cloudflare R2 Public Browser URL Base.',
      format: String,
      default: 'https://assets.kiwishare.online',
      env: 'R2_PUBLIC_URL'
    }
  },
  resend: {
    apiKey: {
      doc: 'Resend API Key for sending verification emails.',
      format: String,
      default: '',
      env: 'RESEND_API_KEY',
      sensitive: true
    },
    from: {
      doc: 'Sender email address for Resend emails.',
      format: String,
      default: 'KiwiShare <onboarding@kiwishare.online>',
      env: 'RESEND_FROM'
    }
  },
  smtp: {
    host: {
      doc: 'SMTP server hostname.',
      format: String,
      default: '',
      env: 'SMTP_HOST'
    },
    port: {
      doc: 'SMTP server port.',
      format: 'port',
      default: 465,
      env: 'SMTP_PORT'
    },
    secure: {
      doc: 'Whether to use TLS/SSL for SMTP connection.',
      format: Boolean,
      default: false,
      env: 'SMTP_SECURE'
    },
    user: {
      doc: 'SMTP authentication username.',
      format: String,
      default: '',
      env: 'SMTP_USER'
    },
    pass: {
      doc: 'SMTP authentication password.',
      format: String,
      default: '',
      env: 'SMTP_PASS',
      sensitive: true
    },
    from: {
      doc: 'Default sender address for SMTP emails.',
      format: String,
      default: '',
      env: 'SMTP_FROM'
    }
  },
  chat: {
    blockedTerms: {
      doc: 'Comma-separated blocked terms for chat message moderation.',
      format: String,
      default: '',
      env: 'CHAT_BLOCKED_TERMS'
    }
  },
  platformFeeRate: {
    doc: 'Platform service fee rate percentage (e.g. 0.01 for 1.0%).',
    format: Number,
    default: 0.01,
    env: 'PLATFORM_FEE_RATE'
  },
  earlyBirdFeeWaiver: {
    doc: 'Whether to waive 100% of platform fees for early-bird launch promo.',
    format: Boolean,
    default: true,
    env: 'EARLY_BIRD_FEE_WAIVER'
  },
  stripe: {
    secretKey: {
      doc: 'Stripe Secret API Key.',
      format: String,
      default: '',
      env: 'STRIPE_SECRET_KEY',
      sensitive: true
    },
    publishableKey: {
      doc: 'Stripe Publishable Key.',
      format: String,
      default: '',
      env: 'STRIPE_PUBLISHABLE_KEY'
    },
    webhookSecret: {
      doc: 'Stripe Webhook Signing Secret.',
      format: String,
      default: '',
      env: 'STRIPE_WEBHOOK_SECRET',
      sensitive: true
    }
  }
});

// Perform validation on the loaded configuration
config.validate({ allowed: 'warn' });

export default config;
