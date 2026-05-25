const workFeed = document.querySelector("#work-feed");
const workEmptyState = document.querySelector("#work-empty-state");
const workCountElements = document.querySelectorAll("[data-work-count]");
const workTemplate = document.querySelector("#work-card-template");
const pageFeed = document.querySelector("#test-page-feed");
const emptyState = document.querySelector("#empty-state");
const pageCountElements = document.querySelectorAll("[data-page-count]");
const postTemplate = document.querySelector("#test-page-card-template");

const setWorkCount = (count) => {
  for (const element of workCountElements) {
    element.textContent = String(count);
  }
};

const setPageCount = (count) => {
  for (const element of pageCountElements) {
    element.textContent = String(count);
  }
};

const getInitial = (title) => {
  const normalizedTitle = String(title || "T").trim();
  return normalizedTitle.length > 0 ? normalizedTitle[0].toUpperCase() : "T";
};

const formatPostDate = (value) => {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "";
  }

  return new Intl.DateTimeFormat("ko-KR", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
};

const renderWorkEmptyState = () => {
  workFeed.replaceChildren();
  setWorkCount(0);
  workEmptyState.hidden = false;
};

const renderWorkPosts = (posts) => {
  workFeed.replaceChildren();
  setWorkCount(posts.length);
  workEmptyState.hidden = posts.length > 0;

  for (const postData of posts) {
    const post = workTemplate.content.firstElementChild.cloneNode(true);
    const avatar = post.querySelector(".work-avatar");
    const category = post.querySelector(".post-category");
    const handle = post.querySelector(".post-handle");
    const status = post.querySelector(".post-status");
    const time = post.querySelector(".post-time");
    const title = post.querySelector("h3");
    const description = post.querySelector(".post-description");
    const fileList = post.querySelector(".work-file-list");
    const link = post.querySelector(".post-action");

    const postTitle = postData.title || "작업 결과 업데이트";
    const postDate = formatPostDate(postData.createdAt);
    const files = Array.isArray(postData.files) ? postData.files : [];

    avatar.textContent = postData.initial || getInitial(postTitle);
    category.textContent = postData.category || "작업 결과";
    handle.textContent = postData.handle || "@codex-hook";
    status.textContent = postData.status || "Ready";
    title.textContent = postTitle;
    description.textContent = postData.summary || "작업 결과가 갱신되었습니다.";

    if (postDate) {
      time.dateTime = postData.createdAt;
      time.textContent = postDate;
    } else {
      time.remove();
    }

    for (const filePath of files.slice(0, 6)) {
      const item = document.createElement("li");
      item.textContent = filePath;
      fileList.append(item);
    }

    if (files.length === 0) {
      fileList.remove();
    }

    if (postData.href) {
      link.href = postData.href;
    } else {
      link.hidden = true;
    }

    workFeed.append(post);
  }
};

const renderEmptyState = () => {
  pageFeed.replaceChildren();
  setPageCount(0);
  emptyState.hidden = false;
};

const renderTestPages = (pages) => {
  pageFeed.replaceChildren();
  setPageCount(pages.length);
  emptyState.hidden = pages.length > 0;

  for (const page of pages) {
    const post = postTemplate.content.firstElementChild.cloneNode(true);
    const avatar = post.querySelector(".test-avatar");
    const category = post.querySelector(".post-category");
    const handle = post.querySelector(".post-handle");
    const status = post.querySelector(".post-status");
    const title = post.querySelector("h3");
    const description = post.querySelector(".post-description");
    const media = post.querySelector(".post-media");
    const image = post.querySelector(".post-media img");
    const link = post.querySelector(".post-action");

    const pageTitle = page.title || "Untitled test";

    avatar.textContent = page.initial || getInitial(pageTitle);
    category.textContent = page.category || "Test page";
    handle.textContent = page.handle || "@test";
    status.textContent = page.status || "Ready";
    title.textContent = pageTitle;
    description.textContent = page.description || "No description yet.";
    if (page.image) {
      image.src = page.image;
      image.alt = page.imageAlt || pageTitle;
      media.hidden = false;
    }
    link.href = page.href || "#";
    link.textContent = page.linkLabel || "서브 페이지 보기";

    pageFeed.append(post);
  }
};

fetch("./data/work-feed.json")
  .then((response) => {
    if (!response.ok) {
      throw new Error(`Failed to load work feed: ${response.status}`);
    }

    return response.json();
  })
  .then((posts) => {
    if (!Array.isArray(posts) || posts.length === 0) {
      renderWorkEmptyState();
      return;
    }

    renderWorkPosts(posts);
  })
  .catch(() => {
    renderWorkEmptyState();
  });

fetch("./data/test-pages.json")
  .then((response) => {
    if (!response.ok) {
      throw new Error(`Failed to load page list: ${response.status}`);
    }

    return response.json();
  })
  .then((pages) => {
    if (!Array.isArray(pages) || pages.length === 0) {
      renderEmptyState();
      return;
    }

    renderTestPages(pages);
  })
  .catch(() => {
    renderEmptyState();
  });
