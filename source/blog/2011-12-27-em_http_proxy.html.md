---
title: EventMachine으로 만든 HTTP 프록시 서버
kind: article
created_at: 2011-12-27
---

### HTTP Proxy 서버

HTTP 클라이언트의 네트워크 요청을 대신 받아서, 불특정 외부 서버에 대한 요청을 대신 처리해주는 중계 서버를 HTTP forward 프록시 서버라고 부릅니다. 다음과 같은 경우에 HTTP Proxy 서버가 유용히 쓰일 수 있습니다.


> 1. 외부 네트워크 트래픽을 줄이거나 속도를 높이기 위한 캐싱(caching)용도
> 1. HTTP 프로토콜 관련한 개발 작업중에 테스트 또는 디버깅 용도
> 1. 공인 IP가 할당되지 않고, NAT도 안걸려있는 사설 IP환경의 서버이거나, 네트워크 보안정책에 의해 외부의 HTTP 접근이 차단된 서버에서 외부 HTTP서버로의 접근이 필요한 경우

만약, 첫번째로 적은 캐싱용도라면 [varnish](https://www.varnish-cache.org/)나 [squid](http://www.squid-cache.org/)를 설치해서 사용했겠습니다만, 제 경우에는 마지막에 해당된 상황이었습니다. 사설IP만 할당된 서버에서 외부 http서버에 접근이 필요해서, 쓸만하고 간단한 HTTP 프록시 서버가 필요했습니다. 성능이나 캐싱처리는 전혀 중요하지 않고, 오로지 간단하게 작동만 되면 되는 경우였죠. 

이런 상황에서 웹(캐싱)서버 다 제외하고, 간단한 프록시를 찾아봤는데, 마땅히 보이지 않더군요. 더 뒤져보면 쓸만한 것을 찾을 수 있을것도 같고, 아니면 아쉬운대로, 위의 서버중에 하나 설치해서 사용할까 하다가...

'에잇, 그냥 하나 만들어보자!'라고

결정했습니다. 제대로 만들려면 맘에 드는 걸 찾는 시간보다 만드는 시간이 더 걸릴지도 모르는 일이었습니다만, 간단한 용도에만 맞춘다면 쉽게 만들 수 있을테고, 또 그렇게 한번쯤 만들어 보는 것도 재밌겠다 싶었던거죠. 이런 마음가짐이 개발자로서 바람직한건지 아닌건지는 미묘하지만 말입니다.

### EventMachine

[EventMachine](http://rubyeventmachine.com/)은 Ruby환경에서 간단하면서도 강력한 기능을 제공하는 네트워크 I/O라이브러리 입니다. 네트워크 클라이언트/서버 프로그램 개발하는데 아주 편리합니다. event-driven방식의 I/O처리로 성능도 좋은데다, 복잡한 멀티쓰레드 처리등이 필요없어서 개발하기 아주 편리합니다. 

아래는 [EventMachine 위키에 있는 예제 코드](https://github.com/eventmachine/eventmachine/wiki/Code-Snippets)중 하나입니다. 

```ruby
require 'rubygems'
require 'eventmachine'

module EchoServer
  def post_init
    puts "-- someone connected to the echo server!"
  end

  def receive_data data
    send_data ">>> you sent: #{data}"
  end
end

EventMachine::run {
  EventMachine::start_server "127.0.0.1", 8081, EchoServer
  puts 'running echo server on 8081'
}
```

이 코드를 실행하면 로컬호스트의 8081번 포트에 직접만든 echo서버가 준비됩니다. telnet등으로 8081포트에 연결해서 확인해볼 수 있습니다. 

예제코드를 간단히 설명해보겠습니다. 맨 아래의 run 메소드에 걸린 블럭 부분이 EchoServer 모듈을 이용해 TCP 서버를 시작하는 코드입니다. 그리고 윗부분의 EchoServer모듈의 post\_init는 클라이언트가 연결된 직후에 실행되는 메소드이고, receive_data는 클라이언트로부터 데이터가 수신되면 불리는 메소드입니다. 

이렇게 간단히, 콜백함수처럼 상황별로 할 일을 코딩해 놓으면, 나머지 복잡한 처리는 EventMachine이 알아서 해주므로 매우 간단하게 네트워크 프로그램을 개발할 수 있습니다. 

### HTTP proxy 서버가 해야할 일은?

[EventMachine](http://rubyeventmachine.com/)을 써서 개발할 것은 미리 정해두었구요, 다음으로, HTTP 프록시 서버가 처리해야하는 일을 고민해보았습니다. 먼저 프록시 서버를 통한 HTTP 요청과 응답은 다음과 같은 과정으로 이루어집니다. 

> 1. HTTP클라이언트에서 쓰고자 하는 프록시 서버의 주소를 설정합니다.
> 1. 이후 해당 클라이언트로부터의 HTTP 요청은 실제 서버대신, 프록시 서버로 오게됩니다. 
> 1. 요청을 대신받은 프록시 서버는 해당 요청이 실제로 가야할 서버로 HTTP커넥션을 연결합니다.
> 1. 프록시는 클라이언트가 보낸 요청 내용을 그대로 HTTP서버로 전달합니다. 
> 1. 프록시는 HTTP서버가 응답하는 내용을 받아서 클라이언트에게 돌려줍니다. 
 
중간에 프록시 서버가 끼어있을뿐, 클라이언트에서 주고 받는 내용은 동일한 것이죠. 1, 2번과정은 기존의 HTTP 클라이언트 프로그램들이 해당기능을 지원하기에 별도로 신경쓸 필요없습니다.

그러면, 프록시 서버를 개발하면 되는데, 프록시 서버측에서 해야할 일 역시 간단합니다. 위의 과정을 프록시 입장에서 개발을 위한 시각으로 다시 살펴보면 다음과 같습니다.

> 1. 클라이언트로 부터 요청을 받으면 Host 헤더를 받을 때까지, 받는 내용을 임시 보관한다. 
> 1. Host헤더를 받으면, 해당 HTTP서버로 별도의 소켓을 연결한다. (클라이언트와의 HTTP 커넥션 유지)
> 1. 1번과정에서 임시로 보관했던 내용(Host 헤더 포함)을 모두 HTTP서버 커넥션에 전달한다.
> 1. 이후, 클라이언트에서 오는 내용은 서버에, 서버에서 오는 내용은 클라이언트에 전달한다.
> 1. 둘중 하나의 커넥션이 끊기면, 다른 한쪽도 끊는다.

별거 없습니다. [Host헤더는 HTTP/1.1 프로토콜상 클라이언트로부터의 요청에서 필수 요소](http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.23)이기 때문에 반드시 포함되어 있습니다. 이 헤더값을 기준으로 처리하는 것이 핵심입니다.

### EventMachine으로 개발한 HTTP proxy 서버

이상의 과정으로 개발한 간단한 [HTTP proxy서버 코드를 github에](https://github.com/hatemogi/em_http_proxy/blob/master/proxy.rb) 올려놓았습니다. 간단히 만들었지만, 종종 유용히 사용할 수 있을거라 기대하구요, 또 개발/테스트 작업에 필요한 경우에 조금씩 코드를 손봐서 사용할 수도 있을 것 같습니다.

> <https://github.com/hatemogi/em_http_proxy/blob/master/proxy.rb>

### 사용방법

ruby가 설치된 환경에서, 우선 eventmachine gem을 설치합니다.
([rbenv](https://github.com/sstephenson/rbenv)나 [rvm](http://beginrescueend.com/)을 쓰신다면, sudo는 필요없습니다)

```sh
sudo gem install eventmachine
```

ruby와 eventmachine이 준비되었다면, 언제든 아래의 커맨드로 실행가능합니다.

```sh
curl -s https://raw.github.com/hatemogi/em_http_proxy/master/proxy.rb | ruby
```

이렇게 프록시 서버를 실행하면, 그 서버나 PC의 IP의 9000번 포트에 HTTP프록시 서버가 준비됩니다.

재미삼아, OSX에 프록시를 띄우고 아래 화면처럼 설정하면, 웹브라우저에서 접근하는 URI가 해당 터미널에 출력됩니다.
 
시스템환경설정 > 네트워크 > 고급 > 프록시 > 웹 프록시 (HTTP) 체크

![OSX에서 웹프록시 설정](/img/em_http_proxy/proxy_setting.png)

웹프록시를 0.0.0.0에 9000번 포트로 지정하고 설정을 승인하고 적용하면, 이후 웹브라우저에서 접근하는 트래픽은 위에서 띄워놓은 프록시 서버를 거치게됩니다. 해당 터미널에 접근하는 URI가 찍히는 것을 확인하실 수 있을거에요. 

외부 네트워크 접근이 차단된 서버에서, 외부접근이 가능한 PC나 게이트웨이 서버에 프록시를 띄워놓고 사용한다면, 대개는 http_proxy환경변수를 설정해서 사용하면 프록시를 타고 나갑니다.

```sh
export http_proxy=http://192.168.0.0:9000/
```

192.168.0.0부분을 게이트웨이 서버나 PC의 IP로 교체해서 설정하면 되는거죠.

이상으로, 지극히 개발자적인 마인드로 HTTP 프록시 서버를 구현해보았습니다. 



