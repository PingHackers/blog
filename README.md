blog
====

PingHackers Blog

### Contribute

Any **original post** are welcomed. Repost would be **rejected**. Don't be worried, translation of high-quality foreign posts are welcomed.

So if you want to join us, you can:

1. Fork this repo

2. Clone the repo and setup develop environment

  ```shell
  git clone git@github.com:yourname/blog.git
  cd blog
  make init # install hexo and required packaages
  make dev # generate public files & run up server
  ```

3. Create a new post, a markdown file `Testing.md` would be created under `source/_posts`

  ```
  hexo n post "Testing"
  ```

4. Open `source/_posts/Testing.md` with your favorite text eitor, write great articles. Check the result in `http://localhost:4000`

5. When you finished, save and commit your work

  ```
  git add .
  git commit -m 'add testing blog'
  git push origin master
  ```

6. Open a pull request, let's rock!
