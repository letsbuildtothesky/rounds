export type AppEnvironment = "local" | "development" | "staging" | "production";

export type ApiConfig = {
  appEnv: AppEnvironment;
  port: number;
  supabaseUrl: string;
  supabasePublishableKey: string;
  supabaseSecretKey: string;
  healthToken: string;
  operationsWebOrigin: string;
};

function required(name: string, env: NodeJS.ProcessEnv): string {
  const value = env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export function readConfig(env: NodeJS.ProcessEnv = process.env): ApiConfig {
  const appEnv = required("APP_ENV", env);
  if (!["local", "development", "staging", "production"].includes(appEnv)) {
    throw new Error("APP_ENV must be local, development, staging or production");
  }
  const port = Number(env.PORT ?? "8080");
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("PORT must be an integer from 1 to 65535");
  }
  return {
    appEnv: appEnv as AppEnvironment,
    port,
    supabaseUrl: required("SUPABASE_URL", env),
    supabasePublishableKey: required("SUPABASE_PUBLISHABLE_KEY", env),
    supabaseSecretKey: required("SUPABASE_SECRET_KEY", env),
    healthToken: required("ROUNDS_HEALTH_TOKEN", env),
    operationsWebOrigin: required("ROUNDS_OPERATIONS_WEB_ORIGIN", env),
  };
}
