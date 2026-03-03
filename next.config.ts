import path from 'path'
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  eslint: {
    // No ESLint config in skeleton — suppress during builds
    ignoreDuringBuilds: true,
  },
  // Silence false-positive warning from parent pnpm-lock.yaml
  outputFileTracingRoot: path.join(__dirname),
}

export default nextConfig
