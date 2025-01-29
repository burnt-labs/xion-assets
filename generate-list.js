import { readdirSync, statSync, writeFileSync, copyFileSync, mkdirSync } from "fs";
import { join, relative, dirname } from "path";
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = join(__filename, '..');
const PUBLIC_DIR = join(__dirname, "public");
const SOURCE_DIR = join(__dirname, "sources");
const OUTPUT_FILE = join(PUBLIC_DIR, "json-files.json");

const getJsonFiles = (dir, baseUrl = "") => {
    let results = [];
    readdirSync(dir).forEach(file => {
        const fullPath = join(dir, file);
        const relativePath = relative(SOURCE_DIR, fullPath); // Relative to sources/

        if (statSync(fullPath).isDirectory()) {
            results = results.concat(getJsonFiles(fullPath, baseUrl)); // Recursively find files
        } else if (file.endsWith(".json") && !file.endsWith("schema.json")) {
            const publicPath = join(PUBLIC_DIR, relativePath);
            mkdirSync(dirname(publicPath), { recursive: true });
            copyFileSync(fullPath, publicPath);
            results.push(`/${relativePath.replace(/\\/g, "/")}`); // Convert Windows \ to /
        }
    });
    return results;
};

// Generate JSON file list
const jsonFiles = getJsonFiles(SOURCE_DIR);
writeFileSync(OUTPUT_FILE, JSON.stringify(jsonFiles, null, 2));

console.log(`✅ JSON file list saved to ${OUTPUT_FILE}`);
