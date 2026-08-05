"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const koa_1 = __importDefault(require("koa"));
const koa_bodyparser_1 = __importDefault(require("koa-bodyparser"));
const error_1 = require("./middleware/error");
const api_1 = __importDefault(require("./routes/api"));
const app = new koa_1.default();
// Hook in body parser and centralized error/stack trace filter
app.use((0, koa_bodyparser_1.default)());
app.use(error_1.errorHandler);
// Enable security headers to prevent tech-stack finger printing
app.use(async (ctx, next) => {
    ctx.remove('X-Powered-By');
    await next();
});
// Configure base API routes
app.use(api_1.default.routes());
app.use(api_1.default.allowedMethods());
exports.default = app;
//# sourceMappingURL=app.js.map