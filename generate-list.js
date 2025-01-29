import { readdirSync, statSync, writeFileSync } from "fs";
import { join, relative } from "path";
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = join(__filename, '..');
const PUBLIC_DIR = join(__dirname, "public");
const OUTPUT_FILE = join(PUBLIC_DIR, "json-files.json");

const getJsonFiles = (dir, baseUrl = "") => {
    let results = [];
    readdirSync(dir).forEach(file => {
        const fullPath = join(dir, file);
        const relativePath = relative(PUBLIC_DIR, fullPath); // Relative to public/

        if (statSync(fullPath).isDirectory()) {
            results = results.concat(getJsonFiles(fullPath, baseUrl)); // Recursively find files
        } else if (file.endsWith(".json") && !file.endsWith("schema.json") && relativePath !== "json-files.json") {
            results.push(`/${relativePath.replace(/\\/g, "/")}`); // Convert Windows \ to /
        }
    });
    return results;
};

// Generate JSON file list
const jsonFiles = getJsonFiles(PUBLIC_DIR);
writeFileSync(OUTPUT_FILE, JSON.stringify(jsonFiles, null, 2));

console.log(`✅ JSON file list saved to ${OUTPUT_FILE}`);
