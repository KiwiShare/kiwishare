import app from './app';

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`\n🚀 [KiwiShare Koa Server] Running locally on http://localhost:${PORT}`);
  console.log(`👋 Development endpoints: http://localhost:${PORT}/api/listings`);
});
