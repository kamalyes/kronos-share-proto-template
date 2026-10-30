const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const file = path.join(__dirname, "extensions.json");

if (!fs.existsSync(file)) {
  console.error("找不到 extensions.json");
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(file, "utf8"));
const extensions = data.extensions || data.recommendations || [];

for (const extension of extensions) {
  console.log(`Installing ${extension}...`);
  execSync(`code --install-extension ${extension}`, { stdio: "inherit" });
}

console.log("All extensions installed.");