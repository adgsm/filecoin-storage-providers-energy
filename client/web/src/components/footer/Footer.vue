<template>
	<section :class="footerClass">
		<div class="attributions">
			<div class="text">{{ $t('message.footer.attributions') }}: </div>
			<div class="attribution">
				<a href="https://www.flaticon.com/free-icons/computer" target="_blank" title="computer icons">vectorsmarket15 - Flaticon</a>
				|
				<a href="https://www.flaticon.com/free-icons/server" target="_blank" title="server icons">Maxim Basinski Premium - Flaticon</a>
			</div>
		</div>
	</section>
</template>

<script src="@/src/js/footer/footer.js" scoped />
<style src="@/src/scss/footer/footer.scss" lang="scss" scoped />
