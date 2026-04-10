import 'dotenv/config';
import express from 'express';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  Environment,
  SignedDataVerifier,
} from '@apple/app-store-server-library';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

const config = {
  port: Number.parseInt(process.env.PORT ?? '8787', 10),
  geminiApiKey: process.env.GEMINI_API_KEY ?? '',
  appBundleId: process.env.APP_BUNDLE_ID ?? '',
  appAppleId: process.env.APP_APPLE_ID ? Number.parseInt(process.env.APP_APPLE_ID, 10) : undefined,
  appleRootCAPaths: (process.env.APPLE_ROOT_CA_PATHS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
    .map((value) => path.resolve(projectRoot, value)),
  allowedProductIDs: new Set(
    (process.env.NANO_BANANA_ALLOWED_PRODUCT_IDS ?? 'com.atelierprime.nanobanana.monthly')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean)
  ),
};

const allowedModels = new Set([
  'gemini-2.5-flash-image',
  'gemini-3.1-flash-image-preview',
  'gemini-3-pro-image-preview',
]);

function assertStartupConfig() {
  const missing = [];
  if (!config.geminiApiKey) missing.push('GEMINI_API_KEY');
  if (!config.appBundleId) missing.push('APP_BUNDLE_ID');
  if (!config.appAppleId) missing.push('APP_APPLE_ID');
  if (config.appleRootCAPaths.length === 0) missing.push('APPLE_ROOT_CA_PATHS');
  if (missing.length > 0) {
    throw new Error(`Missing required environment values: ${missing.join(', ')}`);
  }
}

function loadAppleRootCAs() {
  return config.appleRootCAPaths.map((certificatePath) => fs.readFileSync(certificatePath));
}

const rootCAs = (() => {
  assertStartupConfig();
  return loadAppleRootCAs();
})();

const verifiers = [
  new SignedDataVerifier(
    rootCAs,
    true,
    Environment.SANDBOX,
    config.appBundleId,
    config.appAppleId
  ),
  new SignedDataVerifier(
    rootCAs,
    true,
    Environment.PRODUCTION,
    config.appBundleId,
    config.appAppleId
  ),
];

async function verifyEntitlement(signedTransaction) {
  let lastError;

  for (const verifier of verifiers) {
    try {
      const payload = await verifier.verifyAndDecodeTransaction(signedTransaction);
      const productId = payload.productId;
      const bundleId = payload.bundleId;
      const revocationDate = payload.revocationDate ? Number(payload.revocationDate) : null;
      const expiresDate = payload.expiresDate ? Number(payload.expiresDate) : null;

      if (bundleId !== config.appBundleId) {
        throw new Error(`Bundle identifier mismatch: ${bundleId}`);
      }
      if (!config.allowedProductIDs.has(productId)) {
        throw new Error(`Product is not entitled for Nano Banana: ${productId}`);
      }
      if (revocationDate && revocationDate <= Date.now()) {
        throw new Error('Subscription entitlement was revoked.');
      }
      if (expiresDate && expiresDate <= Date.now()) {
        throw new Error('Subscription entitlement has expired.');
      }

      return payload;
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError ?? new Error('Failed to verify purchase entitlement.');
}

async function generateEditedImage({ prompt, imageBase64, mimeType, model }) {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': config.geminiApiKey,
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
      }),
    }
  );

  const responseText = await response.text();
  if (!response.ok) {
    throw new Error(`Gemini request failed: ${response.status} ${responseText}`);
  }

  const decoded = JSON.parse(responseText);
  for (const candidate of decoded.candidates ?? []) {
    for (const part of candidate.content?.parts ?? []) {
      if (part.inline_data?.data) {
        return part.inline_data.data;
      }
    }
  }

  throw new Error('Gemini response did not contain image data.');
}

const app = express();
app.use(express.json({ limit: '30mb' }));

app.get('/health', (_request, response) => {
  response.json({ ok: true });
});

app.post('/nanobanana/edit', async (request, response) => {
  try {
    const authorization = request.header('Authorization') ?? '';
    const signedTransaction = authorization.startsWith('Bearer ')
      ? authorization.slice('Bearer '.length).trim()
      : '';

    if (!signedTransaction) {
      response.status(401).json({ error: 'Missing bearer entitlement token.' });
      return;
    }

    const { prompt, model, mime_type: mimeType, image_base64: imageBase64 } = request.body ?? {};

    if (typeof prompt !== 'string' || prompt.trim().length === 0) {
      response.status(400).json({ error: 'prompt is required.' });
      return;
    }
    if (typeof mimeType !== 'string' || mimeType.trim().length === 0) {
      response.status(400).json({ error: 'mime_type is required.' });
      return;
    }
    if (typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
      response.status(400).json({ error: 'image_base64 is required.' });
      return;
    }
    if (typeof model !== 'string' || !allowedModels.has(model)) {
      response.status(400).json({ error: 'Unsupported model.' });
      return;
    }

    const entitlement = await verifyEntitlement(signedTransaction);
    const outputImageBase64 = await generateEditedImage({
      prompt: prompt.trim(),
      imageBase64,
      mimeType,
      model,
    });

    response.json({
      image_base64: outputImageBase64,
      product_id: entitlement.productId,
      environment: entitlement.environment,
    });
  } catch (error) {
    response.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown server error.',
    });
  }
});

app.listen(config.port, () => {
  console.log(`Nano Banana proxy listening on :${config.port}`);
});
