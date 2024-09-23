class StripeService
  Stripe.api_key = ENV.fetch('STRIPE_SECRET_API_KEY')
  def initialize(user)
    @user = user
  end

  def create_stripe_product(plan)
    return plan.stripe_product_id if plan.stripe_product_id.present?

    product = Stripe::Product.create({
      name: plan.name,
      type: 'service'
    })
    plan.update!(stripe_product_id: product.id)
    product.id
  end

  def create_stripe_plan(plan)
    return plan.stripe_plan_id if plan.stripe_plan_id.present?

    product_id = create_stripe_product(plan)
    interval = plan.monthly? ? 'month' : 'year'
    amount = (plan.amount * 100).to_i
    currency = plan.currency&.downcase || 'aed'

    stripe_plan = Stripe::Plan.create({
      amount: amount,
      interval: interval,
      product: product_id,
      currency: currency,
      nickname: plan&.name
    })
    plan.update!(stripe_plan_id: stripe_plan.id)
    stripe_plan.id
  end

  def create_stripe_customer
    return @user.stripe_customer_id if @user.stripe_customer_id.present?

    customer = Stripe::Customer.create({
      email: @user.email,
      name: @user&.profile&.full_name
    })
    @user.update!(stripe_customer_id: customer.id, skip_password_validations: true)
    customer.id
  end

  def create_payment_method(card)
    return card.stripe_payment_method_id if card.stripe_payment_method_id.present?

    exp_month, exp_year = card.expires_on.split("/")
    payment_method = Stripe::PaymentMethod.create({
      type: 'card',
      card: {
        token: card.card_token
      }
    })
    card.update!(stripe_payment_method_id: payment_method.id)
    payment_method.id
  end

  def make_subscription_transaction(subscription, customer_id, card)
    payment_method_id = create_payment_method(card)

    attach_payment_method(customer_id, payment_method_id)

    # Create the subscription
    stripe_subscription = Stripe::Subscription.create({
      customer: customer_id,
      items: [{ plan: create_stripe_plan(subscription.plan) }]
    })
    subscription.update!(stripe_subscription_id: stripe_subscription.id, status: "active")
    # register_subscription_transaction(subscription, stripe_subscription)
    stripe_subscription
  end

  def make_subscription_with_trial(subscription, card)
    payment_method_id = create_payment_method(card)
    monthly_plan_id = create_stripe_plan(Plan.find_by(frequency: "monthly"))
    customer_id = create_stripe_customer

    attach_payment_method(customer_id, payment_method_id)

    stripe_subscription = Stripe::Subscription.create({
      trial_period_days: 30,
      customer: customer_id,
      items: [{ plan: monthly_plan_id }]
    })
    subscription.update!(stripe_subscription_id: stripe_subscription.id, status: "trial")
    register_sub_transaction(subscription, stripe_subscription)
    stripe_subscription
  end

  def cancel_stripe_subscription(subscription)
    stripe_subscription = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)
    stripe_subscription.cancel_at_period_end = true
    stripe_subscription.save
  end

  def create_payment_intent(card, amount, currency, desc)
    amount = (amount * 100).to_i
    currency = currency&.downcase || 'aed'
    payment_method_id = create_payment_method(card)
    customer = create_stripe_customer
    description = "#{desc}"

    payment_intent = Stripe::PaymentIntent.create({
      amount: amount,
      currency: currency,
      description: description,
      payment_method: payment_method_id,
      customer: customer,
      confirm: true,
      save_payment_method: true
    })
    # register_single_transaction(payment_intent, amount, currency, desc)
    payment_intent
  end

  # Not used due to PCI DSS complience
  def create_card_token(card)
    Stripe::Token.create(
      card: {
        number: card[:card_number],
        exp_month: card[:expires_on].split('/')[0],
        exp_year: card[:expires_on].split('/')[1],
        cvc: Base64.decode64(card[:cvv])
      }
    )
  end

  def attach_payment_method(customer_id, payment_method_id)
    Stripe::PaymentMethod.attach(
      payment_method_id,
      { customer: customer_id }
    )
    Stripe::Customer.update(
      customer_id,
      invoice_settings: {
        default_payment_method: payment_method_id
      }
    )
  end

  def retrieve_stripe_subscription(subscription_id)
    Stripe::Subscription.retrieve(subscription_id)
  rescue Stripe::InvalidRequestError => e
    Rails.logger.error "Stripe error: #{e.message}"
    nil
  end

end