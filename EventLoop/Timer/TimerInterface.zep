namespace React\EventLoop\Timer;

interface TimerInterface
{
    public function getLoop();
    public function getInterval();
    public function getCallback();
    public function setData(var data);
    public function getData();
    public function isPeriodic();
    public function isActive();
    public function cancel();
}
