<template>
	<section id="hardware" :class="hardwareClass">
		<div v-for="(space, spaceIndex) in spaces" :key="spaceIndex"
			:class="['space-icon', {}]">
			<div class="hardware-container"
				v-show="hardwareExpanded">
				<div v-for="(hw, hwIndex) in hardware[space.Space]" :key="hwIndex"
					:class="['hardware', {}]">
					<div class="hardware-name">{{ hw.Name }}</div>
					<div class="hardware-tags">
						<div v-for="(tag, tagIndex) in hw.Functions" :key="tagIndex"
							:class="['hardware-tag', {
								'core': tag.toLowerCase() == 'core lotus',
								'pc1': tag.toLowerCase() == 'pc1',
								'c1': tag.toLowerCase() == 'c1',
								'pc2': tag.toLowerCase() == 'pc2',
								'c2': tag.toLowerCase() == 'c2',
								'wait': tag.toLowerCase() == 'wait',
								'get': tag.toLowerCase() == 'get',
								'storing': tag.toLowerCase() == 'storing',
								'retrieval': tag.toLowerCase() == 'retrieval',
								'post': tag.toLowerCase() == 'post',
								'solar-generator': tag.toLowerCase() == 'solar generator',
								'power-grid': tag.toLowerCase() == 'power grid'
								}]">
							{{ tag }}
						</div>
					</div>
				</div>
			</div>
			<div class="miners-container">
				<div v-for="(miner, minerIndex) in hardwareMiners[space.Space]" :key="minerIndex"
					:class="['miner', {'active': true}]">
					{{ miner }}
				</div>
			</div>
			<div class="space-name">
				{{ space.Space }}
				<i :class="['pi', 'toggle-button', {'pi-angle-down': !hardwareExpanded, 'pi-angle-up': hardwareExpanded}]"
					@click="hardwareExpanded = !hardwareExpanded"></i>
			</div>
		</div>
	</section>
</template>

<script src="@/src/js/hardware/hardware.js" scoped />
<style src="@/src/scss/hardware/hardware.scss" lang="scss" scoped />
