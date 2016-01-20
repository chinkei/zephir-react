# zephir-react

Event-driven, non-blocking I/O with zephir for php.

使用zephir实现异步非阻塞IO的php C扩展框架, 功能实现自reactphp

## 安装
需要：Libevent；PHP > 5.3;  zephir


```
zephir build
```
```
修改你的php.ini并增加react.so
```
## 使用

Here is an example of a simple TCP server listening on port 8082 by eventloop
```php
<?php
	$loop = React\EventLoop\Factory::create();

    $server = stream_socket_server('tcp://127.0.0.1:8082');
    stream_set_blocking($server, 0);
    $loop->addReadStream($server, function ($server) use ($loop) {
        $conn = stream_socket_accept($server);
        $data = "HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nHi\n";
        $loop->addWriteStream($conn, function ($conn) use (&$data, $loop) {
        	echo (int)$conn;
            $written = fwrite($conn, $data);
            if ($written === strlen($data)) {
                fclose($conn);
                $loop->removeStream($conn);
            } else {
                $data = substr($data, 0, $written);
            }
        });
    });

    $loop->addPeriodicTimer(5, function () {
        $memory = memory_get_usage() / 1024;
        $formatted = number_format($memory, 3).'K';
        echo "Current memory usage: {$formatted}\n";
    });

    $loop->run();
```

## 接下来需要做的组件
```
Http
```
```
Socket
```
```
Steam
```
```
Promise
```
```
Dns
```
And more....
