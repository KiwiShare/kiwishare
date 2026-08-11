/**
 * Custom updater for standard-version to bump version in Flutter's pubspec.yaml
 * Handles version schema: version: major.minor.patch+build
 */
module.exports = {
  readVersion: function (contents) {
    const match = contents.match(/^version:\s*([^\s+]+)(?:\+([^\s]+))?$/m);
    if (!match) {
      throw new Error('Could not find version line in pubspec.yaml');
    }
    // Return the clean semver part (e.g., "1.0.0")
    return match[1];
  },

  writeVersion: function (contents, version) {
    const match = contents.match(/^version:\s*([^\s+]+)(?:\+([^\s]+))?$/m);
    let buildNumber = 1;
    
    if (match && match[2]) {
      const currentBuild = parseInt(match[2], 10);
      if (!isNaN(currentBuild)) {
        buildNumber = currentBuild + 1;
      }
    }
    
    const newVersionLine = `version: ${version}+${buildNumber}`;
    console.log(`Bumping pubspec.yaml version to: ${newVersionLine}`);
    
    return contents.replace(/^version:\s*.*$/m, newVersionLine);
  }
};
