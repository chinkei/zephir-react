namespace React\EventLoop\Timer;

use React\EventLoop\LoopInterface;

class Timer implements TimerInterface
{
    const MIN_INTERVAL = 0.000001;

    protected _loop;
    protected interval;
    protected callback;
    protected periodic;
    protected data;

    public function __construct(<LoopInterface> _loop, float interval, callable callback, boolean periodic = false, array data = null)
    {
        if ( interval < self::MIN_INTERVAL) {
            let interval = self::MIN_INTERVAL;
        }

        let this->_loop = _loop;
        let this->interval = interval;
        let this->callback = callback;
        let this->periodic = periodic;
        let this->data = null;
    }

    public function getLoop()
    {
        return this->_loop;
    }

    public function getInterval()
    {
        return this->interval;
    }

    public function getCallback()
    {
        return this->callback;
    }

    public function setData(var data)
    {
        let this->data = data;
    }

    public function getData()
    {
        return this->data;
    }

    public function isPeriodic()
    {
        return this->periodic;
    }

    public function isActive()
    {
        return this->_loop->isTimerActive(this);
    }

    public function cancel()
    {
        this->_loop->cancelTimer(this);
    }
}