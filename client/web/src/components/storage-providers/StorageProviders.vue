<template>
	<section :class="storageProviderClass">
		<div v-for="(provider, providerIndex) in storageProviders" :key="providerIndex"
			:class="['storage-provider-icon', {'active': provider.Id == storageProvider}]">
			<div class="storage-provider-name">{{ provider.StorageProvider }}</div>
		</div>
	</section>
</template>

<script src="@/src/js/storage-provider/storage-provider.js" scoped />
<style src="@/src/scss/storage-provider/storage-provider.scss" lang="scss" scoped />
