<template>
	<section :class="chartsClass">
		<div class="header">
			<div class="btn">
			<Button :label="$t('message.charts.get-data')" class="p-button-sm p-button p-component p-button-raised" icon="pi pi-check"
				v-show="readyToGetData"
				@click="getData" />
			</div>
			<div class="calendar">
				<Datepicker v-model="dates" range
					@update:modelValue="datesChanged" />
			</div>
		</div>
		<div id="power-chart" class="graphs-container" />
		<div id="solar-power-energy-grid-chart" class="graphs-container" />
	</section>
</template>

<script src="@/src/js/charts/charts.js" scoped />
<style src="@/src/scss/charts/charts.scss" lang="scss" scoped />
