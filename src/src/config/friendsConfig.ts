import type { FriendLink, FriendsPageConfig } from "../types/friendsConfig";

// 可以在src/content/spec/friends.md中编写友链页面下方的自定义内容

// 友链页面配置
export const friendsPageConfig: FriendsPageConfig = {
	// 页面标题，如果留空则使用 i18n 中的翻译
	title: "",

	// 页面描述文本，如果留空则使用 i18n 中的翻译
	description: "",

	// 是否显示底部自定义内容（friends.mdx 中的内容）
	showCustomContent: true,

	// 是否显示评论区，需要先在commentConfig.ts启用评论系统
	showComment: true,

	// 是否开启随机排序配置，如果开启，就会忽略权重，构建时进行一次随机排序
	randomizeSort: false,
};

// 友链配置
export const friendsConfig: FriendLink[] = [
	{
		title: "Peng",
		imgurl: "/images/avatar.png",
		desc: "折腾过的地方，就留下点什么。这是我自己维护的博客。",
		siteurl: "https://github.com/maojiapeng6",
		tags: ["Blog"],
		weight: 10, // 权重，数字越大排序越靠前
		enabled: true, // 是否启用
	},
	{
		title: "Astro Docs",
		imgurl: "https://astro.build/favicon.svg",
		desc: "本站使用的框架官方文档。",
		siteurl: "https://docs.astro.build",
		tags: ["Docs"],
		weight: 9,
		enabled: true,
	},
	{
		title: "Docker Docs",
		imgurl: "https://www.docker.com/favicon.ico",
		desc: "容器化部署时最常翻开的一本书。",
		siteurl: "https://docs.docker.com",
		tags: ["Docs"],
		weight: 8,
		enabled: true,
	},
	{
		title: "Cloudflare Docs",
		imgurl: "https://www.cloudflare.com/favicon.ico",
		desc: "内网穿透与 DNS 配置参考。",
		siteurl: "https://developers.cloudflare.com",
		tags: ["Docs"],
		weight: 7,
		enabled: true,
	},
];

// 获取启用的友链并进行排序
export const getEnabledFriends = (): FriendLink[] => {
	const friends = friendsConfig.filter((friend) => friend.enabled);

	if (friendsPageConfig.randomizeSort) {
		return friends.sort(() => Math.random() - 0.5);
	}

	return friends.sort((a, b) => b.weight - a.weight);
};
