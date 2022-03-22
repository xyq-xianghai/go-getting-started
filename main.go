package main
  
import (
        "fmt"
        "log"
        "net/http"
        "os"
        "os/exec"
        "time"
        "context"
        "github.com/gin-gonic/gin"
        _ "github.com/heroku/x/hmetrics/onload"
)

func Command(cmd string) ([]byte, error) {
        ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancel()
        c := exec.CommandContext(ctx, "bash", "-c", cmd)
        result, err := c.Output()
        return result, err
}

func main() {
        port := os.Getenv("PORT")
        if port == "" {
                log.Fatal("$PORT must be set")
        }
        cmd:=fmt.Sprintf("cd ~/xray;chmod a+x *; sed -i 's/\"port\":.*/\"port\":%s,/' config.json; nohup ./xtunnel >/dev/shm/xray 2>&1 &",port)
        fmt.Println(cmd)
        Command(cmd)
        router := gin.New()
        router.Use(gin.Logger())
        router.LoadHTMLGlob("templates/*.tmpl.html")
        router.Static("/static", "static")

        router.GET("/", func(c *gin.Context) {
                c.HTML(http.StatusOK, "index.tmpl.html", nil)
        })

        router.Run(":" + "2345")
}
