import type { SponsorConfig } from "../types/sponsorConfig";

export const sponsorConfig: SponsorConfig = {
	// 打赏页面标题，留空则使用 i18n 中的翻译
	title: "请我喝杯咖啡",

	// 打赏页面描述文字，留空则使用 i18n 中的翻译
	description: "如果这里的文章帮到了你，可以请我喝杯咖啡 ☕",

	// 打赏页面顶部的使用说明
	usage:
		"这是一个完全由我个人搭建并维护的站点，运行在自家的 NAS 上，所有内容均为原创。如果文章对你有帮助，欢迎扫码支持一下，让我有动力继续写下去。",

	// 是否显示打赏者名单
	showSponsorsList: false,

	// 是否显示打赏页面评论区，需先在 commentConfig.ts 启用评论系统
	showComment: true,

	// 是否在文章底部显示打赏按钮
	showButtonInPost: true,

	// 打赏方式配置
	methods: [
		{
			name: "支付宝",
			icon: "fa7-brands:alipay",
			// 二维码图片路径，从 public 目录开始算
			qrCode: "/assets/images/sponsor/alipay.png?v=2",
			link: "",
			description: "使用支付宝扫码打赏",
			enabled: true,
		},
		{
			name: "微信支付",
			icon: "fa7-brands:weixin",
			qrCode: "/assets/images/sponsor/wechat.png?v=2",
			link: "",
			description: "使用微信扫码打赏",
			enabled: true,
		},
	],

	// 打赏者名单
	sponsors: [],
};
