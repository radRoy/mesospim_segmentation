# template
My template repo including some basic bash scripts for git handling.

--- --- --- --- --- --- --- --- --- ---
## `git` stuff

For a foolproof introduction to handling `git submodule`s, watch this youtube video: <https://www.youtube.com/watch?v=eJrh5IjWSGM> ("Add git submodules to GitHub example").

To avoid unnecessary problems (like python imports from a python file in a git submodule), only use underscores `_` in the repository names and paths, not hyphens (minus, dash) `-`.

So, underscore `_` good:  
**```github.com/user/template_repo```**

...and hyphen (minus, dash) `-` bad:  
```github.com/user/template-repo```

### `git config` stuff

I recommend running these commands with your info when installing git on a new machine:
```
git config --global user.name "User Name"
git config --global user.email user@email.com
git config --global init.defaultbranch "master"
```

You can get info on the current configuration state (`.git/config` file):
```
git config get user.name
git config get user.email
```

### GitHub flavoured Markdown editing notes

Three hyphens `---` is enough to add a horizontal line separator in the GitHub Markdown reading view (as used above). With more hyphens, regardless of spaces between them, GitHub still displays just one horizontal line.

A few hints on adding links and embedding images on github (code chunk content is copied below the chunk, look at it on github.com to see how it should look like).

#### Citing files with hyperlinks:
```
[README] - where the link will be shown

[README]: https://github.com/radRoy/template/blob/master/README.md
hidden in reading mode, requires an empty line, or another link assignment, above
```
[README] - where the link will be shown

[README]: https://github.com/radRoy/template/blob/master/README.md
hidden in reading mode, requires an empty line, or another link assignment, above

#### Embedding an image:
```
![Fiji blobs](https://github.com/radRoy/template/blob/master/resources/blobs.png)  
blobs image caption
```
![Fiji blobs](https://github.com/radRoy/template/blob/master/resources/blobs.png)  
blobs image caption

#### Relative links inside a git repository

Be advised, this is probably specific to GitHub. Here is a link on [GitHub relative link in Markdown file](https://stackoverflow.com/a/7658676).

As an example, instead of this absolute weblink:
```markdown
[GitHub Blog Post about relative links markup (markdown)](https://github.com/radRoy/template/blob/master/resources/Relative_links_in_markup_files%20-%20The_GitHub_Blog.pdf)
```

... one can use relative links that also work in forked GitHub repositories with another web source for a given file:
```markdown
[GitHub Blog Post about relative links markup (markdown)](resources/Relative_links_in_markup_files%20-%20The_GitHub_Blog.pdf)
```
... and should work like this: [GitHub Blog Post about relative links markup (markdown)](resources/Relative_links_in_markup_files%20-%20The_GitHub_Blog.pdf). The `%20` in the markdown souce text is used for a space ` ` in the file path. The original blog post can be found here: [Relative links in markup files](https://github.blog/news-insights/product-news/relative-links-in-markup-files/).
