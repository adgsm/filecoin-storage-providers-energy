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
								'core': hardwareSelected[hw.Name] && tag.toLowerCase() == 'core lotus',
								'pc1': hardwareSelected[hw.Name] && tag.toLowerCase() == 'pc1',
								'c1': hardwareSelected[hw.Name] && tag.toLowerCase() == 'c1',
								'pc2': hardwareSelected[hw.Name] && tag.toLowerCase() == 'pc2',
								'c2': hardwareSelected[hw.Name] && tag.toLowerCase() == 'c2',
								'wait': hardwareSelected[hw.Name] && tag.toLowerCase() == 'wait',
								'get': hardwareSelected[hw.Name] && tag.toLowerCase() == 'get',
								'storing': hardwareSelected[hw.Name] && tag.toLowerCase() == 'storing',
								'retrieval': hardwareSelected[hw.Name] && tag.toLowerCase() == 'retrieval',
								'post': hardwareSelected[hw.Name] && tag.toLowerCase() == 'post',
								'solar-generator': hardwareSelected[hw.Name] && tag.toLowerCase() == 'solar generator',
								'power-grid': hardwareSelected[hw.Name] && tag.toLowerCase() == 'power grid'
								}]">
							{{ tag }}
						</div>
					</div>
					<i :class="['pi', 'hardware-toggle-button', {'pi-circle': !hardwareSelected[hw.Name], 'pi-check-circle': hardwareSelected[hw.Name]}]"
						@click="toggleHardware(hw.Name)"></i>
				</div>
			</div>
			<div class="miners-container">
				<div v-for="(miner, minerIndex) in hardwareMiners[space.Space]" :key="minerIndex"
					:class="['miner', {'active': minersSelected.indexOf(miner) > -1}]"
					@click="toggleMiner(miner)">
					{{ miner }}
				</div>
			</div>
			<div class="space-name">
				<div class="space-name-text">{{ space.Space }}</div>
				<i :class="['pi', 'toggle-button', {'pi-angle-down': !hardwareExpanded, 'pi-angle-up': hardwareExpanded}]"
					@click="hardwareExpanded = !hardwareExpanded"></i>
			</div>
		</div>
	</section>
</template>

<script src="@/src/js/hardware/hardware.js" scoped />
<style src="@/src/scss/hardware/hardware.scss" lang="scss" scoped />
