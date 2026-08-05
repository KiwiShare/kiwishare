"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authenticateToken = authenticateToken;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const JWT_SECRET = process.env.JWT_SECRET || 'kiwishare_super_secret_key_123_abc';
async function authenticateToken(ctx, next) {
    const authHeader = ctx.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        ctx.status = 401;
        ctx.body = { status: 'error', message: 'Access denied. Missing authorization token.' };
        return;
    }
    const token = authHeader.split(' ')[1];
    try {
        const decoded = jsonwebtoken_1.default.verify(token, JWT_SECRET);
        ctx.state.user = decoded; // Store identity in Koa state context
        await next();
    }
    catch (err) {
        ctx.status = 403;
        ctx.body = { status: 'error', message: 'Invalid or expired authorization token.' };
    }
}
//# sourceMappingURL=auth.js.map