<template>
	<section :class="chartsClass">
		<div>
			<Button :label="$t('message.charts.get-data')" class="p-button-sm p-button p-component p-button-raised" icon="pi pi-check"
				v-show="readyToGetData"
				@click="getData" />
		</div>
		<div id="charts" class="graphs-container" />
	</section>
</template>

<script src="@/src/js/charts/charts.js" scoped />
<style src="@/src/scss/charts/charts.scss" lang="scss" scoped />
