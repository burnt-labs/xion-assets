import { readdir, stat, writeFile } from "fs/promises";
import { join, relative } from "path";
import { fileURLToPath } from 'url';
import simpleGit from 'simple-git';
import { mkdir, copyFile } from "fs/promises";

const getJsonFiles = async (sourcesDir, dir, publicDir) => {
    let results = [];
    const files = await readdir(dir, { withFileTypes: true });

    for (const file of files) {
        const fullPath = join(dir, file.name);
        const relativePath = relative(sourcesDir, fullPath); // Relative to public/

        if (file.isDirectory()) {
            const subDirFiles = await getJsonFiles(sourcesDir, fullPath, publicDir); // Recursively find files
            results = results.concat(subDirFiles);
        } else if (file.name.endsWith(".json") && !file.name.endsWith("schema.json")) {
            const publicPath = join(publicDir, relativePath);
            const publicDirPath = join(publicDir, relative(sourcesDir, dir));
            await mkdir(publicDirPath, { recursive: true }); // Create directory if it doesn't exist
            console.log(`Copying file: ${fullPath} to ${publicPath}`);
            await copyFile(fullPath, publicPath); // Copy file to publicDir
            results.push(`/${relativePath.replace(/\\/g, "/")}`); // Convert Windows \ to /
        }
    }
    return results;
};

const initializeGitSubmodules = async (sourcesDir) => {
    const git = simpleGit();

    console.warn("Initializing git submodules, this may take some time...");
    // Initialize git submodules
    await git.submoduleUpdate(['--init']);

    const directories = await readdir(sourcesDir, { withFileTypes: true });

    await Promise.all(directories.map(async dirent => {
        if (dirent.isDirectory()) {
            const dir = dirent.name;
            console.log(`found dir: ${dir}`);
            const submoduleDir = join(sourcesDir, dir);
            const repoGit = simpleGit(submoduleDir);
            const gitDir = (await repoGit.revparse(['--git-dir'])).trim();
            console.log(`setting sparse checkout on: ${dir}`);
            await repoGit.addConfig('core.sparsecheckout', 'true');
            const sparseCheckoutList = (await repoGit.raw(['ls-files', '*xion*.json'])).toString();
            await writeFile(join(gitDir, 'info', 'sparse-checkout'), sparseCheckoutList);
            await repoGit.raw(["read-tree", '-mu', 'HEAD']);
        }
    }));
};

const generateJsonFileList = async () => {
    const filename = fileURLToPath(import.meta.url);
    const dirname = join(filename, '../..');
    const publicDir = join(dirname, "public");
    const outputFile = join(publicDir, "json-files.json");
    const sourcesDir = join(dirname, "sources");

    // Initialize git submodules and set sparse checkout
    await initializeGitSubmodules(sourcesDir);

    // Generate JSON file list
    const jsonFiles = await getJsonFiles(sourcesDir, sourcesDir, publicDir);
    await writeFile(outputFile, JSON.stringify(jsonFiles, null, 2));

    console.log(`✅ JSON file list saved to ${outputFile}`);
};

// Execute the function
generateJsonFileList();

