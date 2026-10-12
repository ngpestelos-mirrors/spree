import * as p from '@clack/prompts'
import { markCommandCancelled } from '@spree/telemetry'
import pc from 'picocolors'
import type { PackageManager, ScaffoldOptions } from './types.js'

interface PromptFlags {
  directory?: string
  noStorefront?: boolean
  noSellerDashboard?: boolean
  noDashboard?: boolean
  noStart?: boolean
  packageManager?: PackageManager
}

export async function runPrompts(
  flags: PromptFlags,
): Promise<Omit<ScaffoldOptions, 'port' | 'mailpitSmtpPort' | 'mailpitUiPort'>> {
  const directory =
    flags.directory ??
    ((await p.text({
      message: 'Where would you like to create your project?',
      placeholder: './my-store',
      defaultValue: './my-store',
      validate(value): string | undefined {
        if (!value) return 'Please enter a directory'
        return undefined
      },
    })) as string)

  if (p.isCancel(directory)) {
    markCommandCancelled()
    p.cancel('Setup cancelled.')
    process.exit(0)
  }

  // Not prompted: nearly every project wants its own copy of the admin to
  // customize. Without one the API still serves the built-in dashboard at
  // /dashboard, so `--no-dashboard` is safe for API-only setups.
  const dashboard = !flags.noDashboard

  let storefront: boolean
  if (flags.noStorefront !== undefined) {
    storefront = !flags.noStorefront
  } else {
    const storefrontResult = await p.confirm({
      message: 'Include Next.js storefront?',
      initialValue: true,
    })

    if (p.isCancel(storefrontResult)) {
      markCommandCancelled()
      p.cancel('Setup cancelled.')
      process.exit(0)
    }
    storefront = storefrontResult
  }

  let sellerDashboard: boolean
  if (flags.noSellerDashboard !== undefined) {
    sellerDashboard = !flags.noSellerDashboard
  } else {
    const sellerResult = await p.confirm({
      message: `Include Seller Panel?\n${pc.dim('Marketplaces only: a dedicated seller panel for your vendors to manage their products, orders and settings')}`,
      initialValue: true,
    })

    if (p.isCancel(sellerResult)) {
      markCommandCancelled()
      p.cancel('Setup cancelled.')
      process.exit(0)
    }
    sellerDashboard = sellerResult
  }

  let start: boolean
  if (flags.noStart !== undefined) {
    start = !flags.noStart
  } else {
    const startResult = await p.confirm({
      message: 'Start services now? Requires Docker - will start Spree server and PostgreSQL',
      initialValue: true,
    })

    if (p.isCancel(startResult)) {
      markCommandCancelled()
      p.cancel('Setup cancelled.')
      process.exit(0)
    }
    start = startResult
  }

  return {
    directory,
    storefront,
    dashboard,
    sellerDashboard,
    start,
    packageManager: flags.packageManager ?? 'npm',
  }
}
