/**
 * Standard-version custom updater for Flutter pubspec.yaml
 * Automatically updates semver and increments build number (e.g. 1.2.0+3)
 */
module.exports.readVersion = function (contents) {
  const match = contents.match(/^version:\s*([^\s+]+)/m);
  return match ? match[1] : '1.0.0';
};

module.exports.writeVersion = function (contents, version) {
  return contents.replace(/^version:\s*([^\s+]+)(?:\+(\d+))?/m, (_, __, buildNum) => {
    const nextBuild = buildNum ? parseInt(buildNum, 10) + 1 : 1;
    return `version: ${version}+${nextBuild}`;
  });
};
