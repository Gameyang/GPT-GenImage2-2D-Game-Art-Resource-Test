const pageFeed = document.querySelector("#test-page-feed");
const emptyState = document.querySelector("#empty-state");
const pageCountElements = document.querySelectorAll("[data-page-count]");
const postTemplate = document.querySelector("#test-page-card-template");

const setPageCount = (count) => {
  for (const element of pageCountElements) {
    element.textContent = String(count);
  }
};

const getInitial = (title) => {
  const normalizedTitle = String(title || "T").trim();
  return normalizedTitle.length > 0 ? normalizedTitle[0].toUpperCase() : "T";
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
    const link = post.querySelector(".post-action");

    const pageTitle = page.title || "Untitled test";

    avatar.textContent = page.initial || getInitial(pageTitle);
    category.textContent = page.category || "Test page";
    handle.textContent = page.handle || "@test";
    status.textContent = page.status || "Ready";
    title.textContent = pageTitle;
    description.textContent = page.description || "No description yet.";
    link.href = page.href || "#";
    link.textContent = page.linkLabel || "서브 페이지 보기";

    pageFeed.append(post);
  }
};

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
