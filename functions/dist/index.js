"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.api = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const app_1 = __importDefault(require("./app"));
const path = __importStar(require("path"));
// Initialize Firebase Admin SDK if not already done in the current context
try {
    let credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    const projectId = process.env.FIREBASE_PROJECT_ID;
    if (credPath) {
        credPath = credPath.trim();
        // Strip surrounding backticks, single quotes, or double quotes
        if ((credPath.startsWith('`') && credPath.endsWith('`')) ||
            (credPath.startsWith('"') && credPath.endsWith('"')) ||
            (credPath.startsWith("'") && credPath.endsWith("'"))) {
            credPath = credPath.slice(1, -1).trim();
        }
        if (credPath.startsWith('{') && credPath.endsWith('}')) {
            // Inline JSON string credentials
            const serviceAccount = JSON.parse(credPath);
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
                projectId: projectId
            });
        }
        else {
            // File path credentials
            const absolutePath = path.isAbsolute(credPath)
                ? credPath
                : path.resolve(__dirname, '..', credPath);
            admin.initializeApp({
                credential: admin.credential.cert(absolutePath),
                projectId: projectId
            });
        }
    }
    else {
        admin.initializeApp();
    }
}
catch (e) {
    // Silent fallback for testing contexts where Firebase credentials are empty
    try {
        admin.initializeApp();
    }
    catch (err) {
        // Ignore if already initialized
    }
}
// Export the Koa app instance as a serverless onRequest function
exports.api = (0, https_1.onRequest)({ cors: true }, app_1.default.callback());
//# sourceMappingURL=index.js.map