/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL?: string;
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_PROXY_TARGET?: string;
  readonly VITE_IOS_APP_URL?: string;
  readonly VITE_ANDROID_APP_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
