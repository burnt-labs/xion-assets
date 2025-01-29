<script setup>
import { ref, onMounted, computed } from "vue";

const jsonfiles = ref([]);

const fetchjsonfiles = async () => {
  try {
    const response = await fetch("/json-files.json"); // load generated file
    jsonfiles.value = await response.json();
  } catch (error) {
    console.error("error loading json file list:", error);
  }
};

const splitfilename = (file) => {
  const parts = file.split('/');
  const basename = parts.pop();
  const dirname = parts.join('/');
  return { dirname, basename };
};

const groupedFiles = computed(() => {
  const groups = {};
  jsonfiles.value.forEach(file => {
    const { dirname, basename } = splitfilename(file);
    if (!groups[dirname]) {
      groups[dirname] = [];
    }
    groups[dirname].push({ file, basename });
  });
  return groups;
});

onMounted(fetchjsonfiles);
</script>

<template>
  <div>
    <h1>XION Assets</h1>
    <div class="file-groups">
      <div v-for="(files, dirname) in groupedFiles" :key="dirname" class="file-group">
        <h2 class="muted">{{ dirname || 'Root' }}</h2>
        <ul>
          <li v-for="file in files" :key="file.file">
            <a :href="file.file" target="_blank" class="bright">{{ file.basename }}</a>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<style>
body {
  font-family: arial, sans-serif;
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  min-height: 100vh;
  margin: 0;
}

ul {
  max-width: 100%;
  overflow-wrap: break-word;
  padding-left: 0;
}

li {
  text-align: left;
}

.muted {
  color: #467eba;
  font-size: 1em;
  /* same size as links */
  text-align: left;
}

.bright {
  color: #00ff00;
  /* terminal green color for basename */
}

.file-groups {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
}

.file-group {
  flex: 1 1 300px;
  /* Adjust the width as needed */
  min-width: 300px;
}
</style>
