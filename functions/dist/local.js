"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("dotenv/config");
const app_1 = __importDefault(require("./app"));
const PORT = process.env.PORT || 3000;
app_1.default.listen(PORT, () => {
    console.log(`\n🚀 [KiwiShare Koa Server] Running locally on http://localhost:${PORT}`);
    console.log(`👋 Development endpoints: http://localhost:${PORT}/api/listings`);
});
//# sourceMappingURL=local.js.map