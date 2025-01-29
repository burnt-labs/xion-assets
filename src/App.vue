<script setup>
import { ref, onMounted } from "vue";

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

onMounted(fetchjsonfiles);
</script>

<template>
  <div>
    <h1>json files in public directory</h1>
    <ul>
      <li v-for="file in jsonfiles" :key="file">
        <a :href="file" target="_blank">
          <span class="muted">{{ splitfilename(file).dirname }}/</span>
          <span class="bright">{{ splitfilename(file).basename }}</span>
        </a>
      </li>
    </ul>
  </div>
</template>

<style>
body {
  font-family: arial, sans-serif;
}

ul {
  padding-left: 0;
}

li {
  text-align: left;
}

.muted {
  color: #467eba;
  /* muted blue color for dirname */
}

.bright {
  color: #00ff00;
  /* terminal green color for basename */
}
</style>
