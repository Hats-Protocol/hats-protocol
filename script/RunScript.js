// script/RunScript.js
const { execSync } = require('child_process');

const scriptName = process.argv[2];
if (!scriptName) {
  console.error('Please provide a script name');
  process.exit(1);
}

execSync(`npx hardhat clean && npx hardhat compile && npx hardhat run script/${scriptName}`, { stdio: 'inherit' });
