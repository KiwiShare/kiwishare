"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = errorHandler;
async function errorHandler(ctx, next) {
    try {
        await next();
    }
    catch (err) {
        // Log the error internally for developer auditing
        console.error(`[API Error Log] Path: ${ctx.path} | Error: ${err.message || err}`);
        // Shield client from sensitive internal stack traces (OWASP Mitigation)
        ctx.status = err.status || 500;
        ctx.body = {
            status: 'error',
            message: err.status && err.status < 500
                ? err.message
                : 'Internal Server Error. Please contact support if this persists.'
        };
    }
}
//# sourceMappingURL=error.js.map