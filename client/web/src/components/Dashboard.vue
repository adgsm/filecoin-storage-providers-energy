<template>
	<section :class="dashboardClass">
		<div class="main-container">
			<div class="storage-providers-container">
				<StorageProviders :storage-provider="storageProvider"
					@storage-provider-changed="(sp) => {storageProvider = sp}" />
			</div>
			<div class="content-container">
				<Hardware :storage-provider="storageProvider"
					@announce-selections="(selections) => {hardwareSelections = selections}" />
				<Charts :storage-provider="storageProvider"
					:hardware-selections="hardwareSelections"
					@loading="(l) => {loading = l}" />
			</div>
		</div>
		<div class="footer-container">
			<Footer />
		</div>
		<div class="loader"
			v-show="loading">
			<ProgressSpinner />
		</div>
	</section>
</template>

<script src="@/src/js/dashboard.js" scoped />
<style src="@/src/scss/dashboard.scss" lang="scss" scoped />
